#!/usr/bin/env python3
"""
Secured Qwen Military NPU Inference Server
With authentication and access controls
"""

import sys
import os
import secrets
import hashlib
from pathlib import Path
import argparse
import json
import time
from typing import Dict, List, Optional, Any
import asyncio
import uuid

# Add torch environment to path
sys.path.insert(0, "/home/john/claude-backups/.torch-venv/lib/python3.13/site-packages")

try:
    from fastapi import FastAPI, HTTPException, Depends, status
    from fastapi.middleware.cors import CORSMiddleware
    from fastapi.responses import StreamingResponse
    from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
    from pydantic import BaseModel, Field
    import uvicorn
    from transformers import AutoTokenizer, AutoModelForCausalLM
    import torch
    print("✅ All dependencies loaded successfully")
except ImportError as e:
    print(f"❌ Import error: {e}")
    sys.exit(1)

# Security configuration
VALID_API_KEYS = {
    "military_npu_key": "claude_military_npu_26_4_tops",
    "agent_system_key": "claude_agent_framework_v7",
    "admin_key": hashlib.sha256("claude_admin_2025".encode()).hexdigest()[:32]
}

security = HTTPBearer()

def verify_api_key(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Verify API key for endpoint access"""
    token = credentials.credentials

    if token not in VALID_API_KEYS.values():
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API key",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return token

# Rate limiting
request_counts = {}
RATE_LIMIT = 60  # requests per minute

def rate_limit_check(api_key: str):
    """Simple rate limiting"""
    current_time = time.time()
    minute_window = int(current_time // 60)

    key = f"{api_key}:{minute_window}"
    request_counts[key] = request_counts.get(key, 0) + 1

    if request_counts[key] > RATE_LIMIT:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Rate limit exceeded"
        )

# OpenAI-compatible models (unchanged)
class ChatMessage(BaseModel):
    role: str
    content: str

class ChatCompletionRequest(BaseModel):
    model: str = "qwen-32b"
    messages: List[ChatMessage]
    temperature: float = 0.7
    max_tokens: Optional[int] = 512
    stream: bool = False

class ChatCompletionChoice(BaseModel):
    index: int
    message: ChatMessage
    finish_reason: str

class ChatCompletionResponse(BaseModel):
    id: str
    object: str = "chat.completion"
    created: int
    model: str
    choices: List[ChatCompletionChoice]
    usage: Dict[str, int]

class SecureQwenEngine:
    """Secure Qwen inference engine with monitoring"""

    def __init__(self, model_path: str = "/home/john/claude-backups/local-models/qwen-raw"):
        self.model_path = Path(model_path)
        self.model = None
        self.tokenizer = None

        # Security monitoring
        self.security_stats = {
            "total_requests": 0,
            "authenticated_requests": 0,
            "rejected_requests": 0,
            "rate_limited_requests": 0,
            "start_time": time.time()
        }

        # Performance stats
        self.performance_stats = {
            "requests_processed": 0,
            "tokens_generated": 0,
            "total_time": 0.0,
            "average_tokens_per_second": 0.0
        }

        print(f"🔒 Initializing Secure Qwen Military NPU Engine")
        self._load_model()

    def _load_model(self):
        """Load Qwen model securely"""
        try:
            print("📖 Loading tokenizer...")
            self.tokenizer = AutoTokenizer.from_pretrained(
                self.model_path,
                trust_remote_code=True
            )

            print("🧠 Loading model...")
            self.model = AutoModelForCausalLM.from_pretrained(
                self.model_path,
                torch_dtype=torch.float16,
                device_map="auto",
                trust_remote_code=True,
                low_cpu_mem_usage=True
            )

            print("✅ Secure model loaded successfully!")

        except Exception as e:
            print(f"❌ Model loading failed: {e}")
            self.model = None

    async def generate_secure_response(self, request: ChatCompletionRequest, api_key: str) -> ChatCompletionResponse:
        """Generate response with security logging"""

        # Security checks
        rate_limit_check(api_key)

        self.security_stats["total_requests"] += 1
        self.security_stats["authenticated_requests"] += 1

        if not self.model:
            raise HTTPException(status_code=503, detail="Model not loaded")

        start_time = time.time()

        try:
            # Format and generate response (same as before)
            prompt = self._format_chat_prompt(request.messages)
            inputs = self.tokenizer(prompt, return_tensors="pt")
            input_length = inputs.input_ids.shape[1]

            with torch.no_grad():
                outputs = self.model.generate(
                    **inputs,
                    max_new_tokens=request.max_tokens or 512,
                    temperature=request.temperature,
                    do_sample=request.temperature > 0.0,
                    pad_token_id=self.tokenizer.eos_token_id,
                    use_cache=True
                )

            response_tokens = outputs[0][input_length:]
            response_text = self.tokenizer.decode(response_tokens, skip_special_tokens=True)
            response_text = response_text.replace("<|im_end|>", "").strip()

            # Update stats
            processing_time = time.time() - start_time
            output_length = len(response_tokens)

            self.performance_stats["requests_processed"] += 1
            self.performance_stats["tokens_generated"] += output_length
            self.performance_stats["total_time"] += processing_time
            self.performance_stats["average_tokens_per_second"] = (
                self.performance_stats["tokens_generated"] / self.performance_stats["total_time"]
            )

            print(f"🔒 Secure inference: {output_length} tokens, {output_length/processing_time:.1f} tok/s")

            return ChatCompletionResponse(
                id=str(uuid.uuid4()),
                created=int(time.time()),
                model=request.model,
                choices=[ChatCompletionChoice(
                    index=0,
                    message=ChatMessage(role="assistant", content=response_text),
                    finish_reason="stop"
                )],
                usage={
                    "prompt_tokens": input_length,
                    "completion_tokens": output_length,
                    "total_tokens": input_length + output_length
                }
            )

        except Exception as e:
            self.security_stats["rejected_requests"] += 1
            raise HTTPException(status_code=500, detail=f"Inference failed: {str(e)}")

    def _format_chat_prompt(self, messages: List[ChatMessage]) -> str:
        """Format chat prompt for Qwen"""
        formatted = []
        for msg in messages:
            if msg.role == "system":
                formatted.append(f"<|im_start|>system\n{msg.content}<|im_end|>")
            elif msg.role == "user":
                formatted.append(f"<|im_start|>user\n{msg.content}<|im_end|>")
            elif msg.role == "assistant":
                formatted.append(f"<|im_start|>assistant\n{msg.content}<|im_end|>")
        formatted.append("<|im_start|>assistant")
        return "\n".join(formatted)

    def get_security_stats(self) -> Dict[str, Any]:
        """Get security statistics"""
        uptime = time.time() - self.security_stats["start_time"]
        return {
            **self.security_stats,
            "uptime_seconds": uptime,
            "requests_per_minute": self.security_stats["total_requests"] / (uptime / 60) if uptime > 0 else 0
        }

# Create secured FastAPI app
app = FastAPI(
    title="Secured Qwen Military NPU Server",
    description="Military-grade secure local inference",
    version="1.0.0-secure"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:*"],  # Restricted origins
    allow_credentials=True,
    allow_methods=["GET", "POST"],  # Limited methods
    allow_headers=["Authorization", "Content-Type"],
)

# Initialize secure engine
engine = SecureQwenEngine()

@app.post("/v1/chat/completions")
async def secure_chat_completions(
    request: ChatCompletionRequest,
    api_key: str = Depends(verify_api_key)
):
    """Secured chat completions endpoint"""
    return await engine.generate_secure_response(request, api_key)

@app.get("/health")
async def health():
    """Public health endpoint (no auth required)"""
    return {
        "status": "secure",
        "model_loaded": engine.model is not None,
        "npu_available": Path("/dev/accel/accel0").exists(),
        "authentication": "enabled",
        "rate_limiting": "active"
    }

@app.get("/admin/stats")
async def admin_stats(api_key: str = Depends(verify_api_key)):
    """Admin statistics endpoint"""
    if api_key != VALID_API_KEYS["admin_key"]:
        raise HTTPException(status_code=403, detail="Admin access required")

    return {
        "security": engine.get_security_stats(),
        "performance": engine.performance_stats,
        "hardware": {
            "npu_available": Path("/dev/accel/accel0").exists(),
            "npu_tops": 26.4
        }
    }

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8001)  # Different port
    parser.add_argument("--host", type=str, default="127.0.0.1")  # Localhost only
    args = parser.parse_args()

    print("🔒 Starting Secured Qwen Military NPU Server")
    print(f"🎯 Authentication: Enabled")
    print(f"📡 Server: http://localhost:{args.port}")
    print(f"🔑 API Keys required for /v1/chat/completions")

    uvicorn.run(app, host=args.host, port=args.port)