from fastapi import FastAPI, HTTPException, UploadFile, File, Query
from fastapi.responses import StreamingResponse, HTMLResponse
import boto3
from botocore.exceptions import ClientError
import os
import io

app = FastAPI(
    title="MinVault Portal API",
    description="API de gestion de fichiers pour MinVault",
    version="1.3.0"
)

S3_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://minio1:9000")
S3_ACCESS_KEY = os.getenv("MINIO_ROOT_USER", "vaultadmin")
S3_SECRET_KEY = os.getenv("MINIO_ROOT_PASSWORD", "vaultadminsecret")

def get_s3_client():
    return boto3.client(
        "s3",
        endpoint_url=S3_ENDPOINT,
        aws_access_key_id=S3_ACCESS_KEY,
        aws_secret_access_key=S3_SECRET_KEY,
        verify=False
    )

@app.get("/", response_class=HTMLResponse)
def index():
    return """
    <!DOCTYPE html>
    <html>
    <head>
        <title>MinVault Portal</title>
        <style>
            body { font-family: sans-serif; margin: 40px; background: #f4f6f8; }
            h1 { color: #333; }
            .card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
            a { color: #0066cc; text-decoration: none; }
        </style>
    </head>
    <body>
        <div class="card">
            <h1>🗄️ Portail MinVault (v1.3)</h1>
            <p>Bienvenue sur le portail applicatif MinVault.</p>
            <ul>
                <li><a href="/docs">Documentation OpenAPI / Swagger</a></li>
                <li><a href="/buckets">Lister les Buckets</a></li>
            </ul>
        </div>
    </body>
    </html>
    """

@app.get("/buckets")
def list_buckets():
    s3 = get_s3_client()
    try:
        response = s3.list_buckets()
        return [b["Name"] for b in response.get("Buckets", [])]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/files/{bucket}")
def list_files(bucket: str, prefix: str = ""):
    s3 = get_s3_client()
    try:
        response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
        contents = response.get("Contents", [])
        return [{"Key": obj["Key"], "Size": obj["Size"], "LastModified": obj["LastModified"].isoformat()} for obj in contents]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/upload/{bucket}")
async def upload_file(bucket: str, file: UploadFile = File(...)):
    s3 = get_s3_client()
    try:
        contents = await file.read()
        s3.put_object(Bucket=bucket, Key=file.filename, Body=contents)
        return {"filename": file.filename, "status": "uploaded", "bucket": bucket}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/download/{bucket}/{key:path}")
def download_file(bucket: str, key: str):
    s3 = get_s3_client()
    try:
        obj = s3.get_object(Bucket=bucket, Key=key)
        return StreamingResponse(
            io.BytesIO(obj["Body"].read()),
            media_type=obj.get("ContentType", "application/octet-stream"),
            headers={"Content-Disposition": f'attachment; filename="{os.path.basename(key)}"'}
        )
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchKey':
            raise HTTPException(status_code=404, detail="Fichier introuvable")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/presigned-url/{bucket}/{key:path}")
def generate_presigned_url(bucket: str, key: str, expires_in: int = Query(3600)):
    s3 = get_s3_client()
    try:
        url = s3.generate_presigned_url(
            'get_object',
            Params={'Bucket': bucket, 'Key': key},
            ExpiresIn=expires_in
        )
        return {"url": url, "expires_in": expires_in}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
