from fastapi import FastAPI, HTTPException, logger
from pydantic import BaseModel
import uvicorn

app = FastAPI()

# Define the request model
class RankRequest(BaseModel):
    rank: int
    ip: str = None

# In-memory storage for the IP address
ip_storage = {}

@app.post("/")
async def handle_rank(request: RankRequest):
    if request.rank == 0:
        if request.ip:
            ip_storage['ip'] = request.ip
            # logger.info(f"IP address saved: {request.ip}")
            logger.logger.info(f"IP address saved: {request.ip}")
            return {"message": "IP address saved"}
        else:
            raise HTTPException(status_code=400, detail="IP address is required for rank 0")
    else:
        if 'ip' in ip_storage:
            logger.logger.info(f"IP address retrieved: {ip_storage['ip']}")
            return {"ip": ip_storage['ip']}
        else:
            raise HTTPException(status_code=404, detail="IP address not found")

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)