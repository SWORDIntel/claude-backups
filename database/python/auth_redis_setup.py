#!/usr/bin/env python3
"""
Claude Agent Framework - Redis Authentication Caching Layer
Database Agent Redis Integration v1.0

High-performance Redis caching layer for authentication system:
- Session storage with TTL management
- JWT token blacklisting  
- Rate limiting with sliding windows
- Permission caching for fast RBAC checks
- User lookup acceleration

Compatible with auth_security.h/.c and PostgreSQL schema.
"""

import asyncio
import redis.asyncio as redis
import json
import time
import hashlib
import logging
from typing import Dict, List, Optional, Set, Any
from dataclasses import dataclass, asdict
from datetime import datetime, timedelta
import secrets

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger('auth_redis_setup')

@dataclass
class SessionData:
    """Session data structure for Redis storage"""
    user_id: str
    username: str
    roles: List[str]
    permissions: List[str]
    permission_bitmask: int
    expires_at: str
    ip_address: str
    last_activity: str
    login_method: str = 'password'

@dataclass
class RateLimitBucket:
    """Rate limiting bucket data"""
    identifier: str
    identifier_type: str  # 'ip', 'user', 'api_key'
    window_start: int
    request_count: int
    max_requests: int
    blocked_until: Optional[int] = None

class AuthRedisManager:
    """Redis authentication cache manager"""
    
    # Redis key prefixes
    SESSION_PREFIX = "session"
    TOKEN_BLACKLIST_PREFIX = "blacklist"
    TOKEN_VALID_PREFIX = "token_valid"
    USER_PERMS_PREFIX = "user_perms"
    ROLE_PERMS_PREFIX = "role_perms"
    RATE_LIMIT_PREFIX = "rate_limit"
    RATE_BUCKET_PREFIX = "bucket"
    USER_SESSIONS_PREFIX = "user_sessions"
    
    # Default TTL values (seconds)
    SESSION_TTL = 86400  # 24 hours
    TOKEN_CACHE_TTL = 300  # 5 minutes
    PERMISSION_CACHE_TTL = 900  # 15 minutes
    ROLE_CACHE_TTL = 3600  # 1 hour
    RATE_LIMIT_WINDOW = 60  # 1 minute
    
    def __init__(self, redis_url: str = "redis://localhost:6379/0"):
        self.redis_url = redis_url
        self.redis_client = None
    
    async def initialize(self):
        """Initialize Redis connection"""
        logger.info("Initializing Redis authentication cache...")
        
        try:
            self.redis_client = redis.from_url(
                self.redis_url,
                decode_responses=True,
                max_connections=100,
                retry_on_timeout=True,
                health_check_interval=30
            )
            
            # Test connection
            await self.redis_client.ping()
            logger.info("Redis connection established successfully")
            
            # Setup cache warming
            await self.setup_cache_warming()
            
        except Exception as e:
            logger.error(f"Failed to initialize Redis: {e}")
            raise
    
    async def close(self):
        """Close Redis connection"""
        if self.redis_client:
            await self.redis_client.close()
    
    # ========================================================================
    # SESSION MANAGEMENT
    # ========================================================================
    
    async def store_session(self, session_id: str, session_data: SessionData) -> bool:
        """Store session data in Redis"""
        try:
            key = f"{self.SESSION_PREFIX}:{session_id}"
            data = json.dumps(asdict(session_data))
            
            # Calculate TTL based on session expiry
            expires_at = datetime.fromisoformat(session_data.expires_at.replace('Z', '+00:00'))
            ttl = int((expires_at - datetime.now()).total_seconds())
            
            if ttl <= 0:
                logger.warning(f"Session {session_id} already expired")
                return False
            
            # Store session data
            await self.redis_client.setex(key, ttl, data)
            
            # Add to user's active sessions set
            user_sessions_key = f"{self.USER_SESSIONS_PREFIX}:{session_data.user_id}"
            await self.redis_client.sadd(user_sessions_key, session_id)
            await self.redis_client.expire(user_sessions_key, ttl)
            
            logger.debug(f"Stored session {session_id} for user {session_data.username}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to store session {session_id}: {e}")
            return False
    
    async def get_session(self, session_id: str) -> Optional[SessionData]:
        """Retrieve session data from Redis"""
        try:
            key = f"{self.SESSION_PREFIX}:{session_id}"
            data = await self.redis_client.get(key)
            
            if not data:
                return None
            
            session_dict = json.loads(data)
            return SessionData(**session_dict)
            
        except Exception as e:
            logger.error(f"Failed to get session {session_id}: {e}")
            return None
    
    async def delete_session(self, session_id: str, user_id: str = None) -> bool:
        """Delete session from Redis"""
        try:
            key = f"{self.SESSION_PREFIX}:{session_id}"
            deleted = await self.redis_client.delete(key)
            
            # Remove from user's active sessions if user_id provided
            if user_id:
                user_sessions_key = f"{self.USER_SESSIONS_PREFIX}:{user_id}"
                await self.redis_client.srem(user_sessions_key, session_id)
            
            return deleted > 0
            
        except Exception as e:
            logger.error(f"Failed to delete session {session_id}: {e}")
            return False
    
    async def get_user_sessions(self, user_id: str) -> Set[str]:
        """Get all active sessions for a user"""
        try:
            key = f"{self.USER_SESSIONS_PREFIX}:{user_id}"
            sessions = await self.redis_client.smembers(key)
            return set(sessions) if sessions else set()
            
        except Exception as e:
            logger.error(f"Failed to get user sessions for {user_id}: {e}")
            return set()
    
    async def update_session_activity(self, session_id: str) -> bool:
        """Update last activity timestamp for session"""
        try:
            session_data = await self.get_session(session_id)
            if not session_data:
                return False
            
            session_data.last_activity = datetime.now().isoformat() + 'Z'
            return await self.store_session(session_id, session_data)
            
        except Exception as e:
            logger.error(f"Failed to update session activity {session_id}: {e}")
            return False
    
    # ========================================================================
    # JWT TOKEN MANAGEMENT
    # ========================================================================
    
    async def blacklist_token(self, jti: str, expires_at: datetime) -> bool:
        """Add JWT token to blacklist"""
        try:
            key = f"{self.TOKEN_BLACKLIST_PREFIX}:{jti}"
            ttl = int((expires_at - datetime.now()).total_seconds())
            
            if ttl <= 0:
                return True  # Already expired
            
            await self.redis_client.setex(key, ttl, "1")
            logger.debug(f"Blacklisted token {jti}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to blacklist token {jti}: {e}")
            return False
    
    async def is_token_blacklisted(self, jti: str) -> bool:
        """Check if JWT token is blacklisted"""
        try:
            key = f"{self.TOKEN_BLACKLIST_PREFIX}:{jti}"
            result = await self.redis_client.exists(key)
            return result > 0
            
        except Exception as e:
            logger.error(f"Failed to check token blacklist {jti}: {e}")
            return False
    
    async def cache_token_validation(self, token_hash: str, is_valid: bool) -> bool:
        """Cache token validation result"""
        try:
            key = f"{self.TOKEN_VALID_PREFIX}:{token_hash}"
            value = "1" if is_valid else "0"
            await self.redis_client.setex(key, self.TOKEN_CACHE_TTL, value)
            return True
            
        except Exception as e:
            logger.error(f"Failed to cache token validation {token_hash}: {e}")
            return False
    
    async def get_cached_token_validation(self, token_hash: str) -> Optional[bool]:
        """Get cached token validation result"""
        try:
            key = f"{self.TOKEN_VALID_PREFIX}:{token_hash}"
            result = await self.redis_client.get(key)
            
            if result is None:
                return None
            
            return result == "1"
            
        except Exception as e:
            logger.error(f"Failed to get cached token validation {token_hash}: {e}")
            return None
    
    # ========================================================================
    # PERMISSION CACHING
    # ========================================================================
    
    async def cache_user_permissions(self, user_id: str, roles: List[str], 
                                   permissions: List[str], permission_bitmask: int) -> bool:
        """Cache user permissions for fast RBAC checks"""
        try:
            key = f"{self.USER_PERMS_PREFIX}:{user_id}"
            data = {
                'roles': roles,
                'permissions': permissions,
                'permission_bitmask': permission_bitmask,
                'cached_at': time.time()
            }
            
            await self.redis_client.setex(key, self.PERMISSION_CACHE_TTL, json.dumps(data))
            logger.debug(f"Cached permissions for user {user_id}")
            return True
            
        except Exception as e:
            logger.error(f"Failed to cache user permissions {user_id}: {e}")
            return False
    
    async def get_cached_user_permissions(self, user_id: str) -> Optional[Dict[str, Any]]:
        """Get cached user permissions"""
        try:
            key = f"{self.USER_PERMS_PREFIX}:{user_id}"
            data = await self.redis_client.get(key)
            
            if not data:
                return None
            
            return json.loads(data)
            
        except Exception as e:
            logger.error(f"Failed to get cached user permissions {user_id}: {e}")
            return None
    
    async def cache_role_permissions(self, role_name: str, permissions: List[str]) -> bool:
        """Cache role permissions"""
        try:
            key = f"{self.ROLE_PERMS_PREFIX}:{role_name}"
            await self.redis_client.setex(key, self.ROLE_CACHE_TTL, json.dumps(permissions))
            return True
            
        except Exception as e:
            logger.error(f"Failed to cache role permissions {role_name}: {e}")
            return False
    
    async def get_cached_role_permissions(self, role_name: str) -> Optional[List[str]]:
        """Get cached role permissions"""
        try:
            key = f"{self.ROLE_PERMS_PREFIX}:{role_name}"
            data = await self.redis_client.get(key)
            
            if not data:
                return None
            
            return json.loads(data)
            
        except Exception as e:
            logger.error(f"Failed to get cached role permissions {role_name}: {e}")
            return None
    
    async def invalidate_user_permissions(self, user_id: str) -> bool:
        """Invalidate cached user permissions"""
        try:
            key = f"{self.USER_PERMS_PREFIX}:{user_id}"
            deleted = await self.redis_client.delete(key)
            return deleted > 0
            
        except Exception as e:
            logger.error(f"Failed to invalidate user permissions {user_id}: {e}")
            return False
    
    # ========================================================================
    # RATE LIMITING
    # ========================================================================
    
    async def check_rate_limit(self, identifier: str, identifier_type: str, 
                              max_requests: int = 1000, window_seconds: int = 60) -> Dict[str, Any]:
        """Check rate limit using sliding window algorithm"""
        try:
            now = int(time.time())
            window_start = now - window_seconds
            
            # Rate limit key for sliding window
            key = f"{self.RATE_LIMIT_PREFIX}:{identifier_type}:{identifier}"
            
            # Use pipeline for atomic operations
            pipe = self.redis_client.pipeline()
            
            # Remove old entries
            pipe.zremrangebyscore(key, 0, window_start)
            
            # Count current requests
            pipe.zcard(key)
            
            # Add current request
            pipe.zadd(key, {str(now): now})
            
            # Set expiry
            pipe.expire(key, window_seconds)
            
            results = await pipe.execute()
            current_count = results[1]
            
            # Check if blocked
            block_key = f"{self.RATE_BUCKET_PREFIX}:{identifier_type}:{identifier}:blocked"
            blocked_until = await self.redis_client.get(block_key)
            
            is_blocked = False
            if blocked_until and int(blocked_until) > now:
                is_blocked = True
            
            # Check if limit exceeded
            limit_exceeded = current_count >= max_requests
            
            if limit_exceeded and not is_blocked:
                # Block for 1 minute
                block_until = now + 60
                await self.redis_client.setex(block_key, 60, str(block_until))
                is_blocked = True
            
            return {
                'allowed': not is_blocked and not limit_exceeded,
                'current_count': current_count,
                'max_requests': max_requests,
                'window_seconds': window_seconds,
                'blocked': is_blocked,
                'blocked_until': int(blocked_until) if blocked_until else None,
                'reset_time': now + window_seconds
            }
            
        except Exception as e:
            logger.error(f"Failed to check rate limit {identifier}: {e}")
            return {'allowed': True, 'error': str(e)}
    
    async def get_rate_limit_info(self, identifier: str, identifier_type: str) -> Dict[str, Any]:
        """Get rate limit information without incrementing"""
        try:
            now = int(time.time())
            window_start = now - self.RATE_LIMIT_WINDOW
            
            key = f"{self.RATE_LIMIT_PREFIX}:{identifier_type}:{identifier}"
            current_count = await self.redis_client.zcount(key, window_start, now)
            
            block_key = f"{self.RATE_BUCKET_PREFIX}:{identifier_type}:{identifier}:blocked"
            blocked_until = await self.redis_client.get(block_key)
            
            return {
                'current_count': current_count,
                'blocked': blocked_until is not None and int(blocked_until) > now,
                'blocked_until': int(blocked_until) if blocked_until else None
            }
            
        except Exception as e:
            logger.error(f"Failed to get rate limit info {identifier}: {e}")
            return {'error': str(e)}
    
    # ========================================================================
    # CACHE WARMING AND MAINTENANCE
    # ========================================================================
    
    async def setup_cache_warming(self):
        """Setup cache warming strategies"""
        logger.info("Setting up Redis cache warming...")
        
        # This would typically be called from a background task
        # that periodically warms the cache with frequently accessed data
        
        # Example: Pre-populate frequently used role permissions
        default_roles = ['admin', 'system', 'agent', 'monitor', 'guest']
        for role in default_roles:
            # In a real implementation, this would fetch from database
            permissions = await self.get_default_role_permissions(role)
            await self.cache_role_permissions(role, permissions)
    
    async def get_default_role_permissions(self, role_name: str) -> List[str]:
        """Get default permissions for built-in roles"""
        role_permissions = {
            'admin': ['read', 'write', 'execute', 'admin', 'monitor', 'system'],
            'system': ['read', 'write', 'execute', 'system'],
            'agent': ['read', 'write', 'execute'],
            'monitor': ['read', 'monitor'],
            'guest': ['read']
        }
        return role_permissions.get(role_name, ['read'])
    
    async def cleanup_expired_data(self):
        """Clean up expired data from Redis"""
        try:
            logger.info("Starting Redis cleanup...")
            
            # Clean up expired rate limit entries
            now = int(time.time())
            pattern = f"{self.RATE_LIMIT_PREFIX}:*"
            
            async for key in self.redis_client.scan_iter(match=pattern):
                # Remove entries older than 5 minutes
                await self.redis_client.zremrangebyscore(key, 0, now - 300)
            
            # Clean up expired session references
            pattern = f"{self.USER_SESSIONS_PREFIX}:*"
            async for key in self.redis_client.scan_iter(match=pattern):
                # Remove sessions that no longer exist
                session_ids = await self.redis_client.smembers(key)
                for session_id in session_ids:
                    session_key = f"{self.SESSION_PREFIX}:{session_id}"
                    if not await self.redis_client.exists(session_key):
                        await self.redis_client.srem(key, session_id)
            
            logger.info("Redis cleanup completed")
            
        except Exception as e:
            logger.error(f"Redis cleanup failed: {e}")
    
    async def get_cache_statistics(self) -> Dict[str, Any]:
        """Get Redis cache statistics"""
        try:
            info = await self.redis_client.info()
            
            # Count keys by type
            key_counts = {}
            for prefix in [self.SESSION_PREFIX, self.TOKEN_BLACKLIST_PREFIX, 
                          self.USER_PERMS_PREFIX, self.RATE_LIMIT_PREFIX]:
                pattern = f"{prefix}:*"
                count = 0
                async for _ in self.redis_client.scan_iter(match=pattern):
                    count += 1
                key_counts[prefix] = count
            
            return {
                'redis_version': info.get('redis_version'),
                'memory_used': info.get('used_memory_human'),
                'memory_peak': info.get('used_memory_peak_human'),
                'connected_clients': info.get('connected_clients'),
                'total_commands_processed': info.get('total_commands_processed'),
                'keyspace_hits': info.get('keyspace_hits'),
                'keyspace_misses': info.get('keyspace_misses'),
                'hit_ratio': float(info.get('keyspace_hits', 0)) / max(float(info.get('keyspace_hits', 0)) + float(info.get('keyspace_misses', 0)), 1) * 100,
                'key_counts': key_counts
            }
            
        except Exception as e:
            logger.error(f"Failed to get cache statistics: {e}")
            return {'error': str(e)}

async def setup_redis_auth_cache():
    """Setup and test Redis authentication cache"""
    logger.info("Setting up Redis authentication cache...")
    
    redis_manager = AuthRedisManager()
    
    try:
        await redis_manager.initialize()
        
        # Test basic functionality
        logger.info("Testing Redis cache functionality...")
        
        # Test session storage
        test_session = SessionData(
            user_id="test-user-id",
            username="testuser",
            roles=["agent"],
            permissions=["read", "write", "execute"],
            permission_bitmask=7,  # 1|2|4 = 7
            expires_at=(datetime.now() + timedelta(hours=1)).isoformat() + 'Z',
            ip_address="127.0.0.1",
            last_activity=datetime.now().isoformat() + 'Z'
        )
        
        session_id = "test-session-" + secrets.token_urlsafe(16)
        await redis_manager.store_session(session_id, test_session)
        
        # Test session retrieval
        retrieved_session = await redis_manager.get_session(session_id)
        if retrieved_session:
            logger.info("✓ Session storage/retrieval working")
        else:
            logger.error("✗ Session storage/retrieval failed")
        
        # Test permission caching
        await redis_manager.cache_user_permissions(
            "test-user-id", ["agent"], ["read", "write", "execute"], 7
        )
        
        cached_perms = await redis_manager.get_cached_user_permissions("test-user-id")
        if cached_perms:
            logger.info("✓ Permission caching working")
        else:
            logger.error("✗ Permission caching failed")
        
        # Test rate limiting
        rate_result = await redis_manager.check_rate_limit("test-user", "user", 10, 60)
        if rate_result.get('allowed'):
            logger.info("✓ Rate limiting working")
        else:
            logger.error("✗ Rate limiting failed")
        
        # Test JWT blacklisting
        test_jti = "test-jwt-" + secrets.token_urlsafe(16)
        await redis_manager.blacklist_token(test_jti, datetime.now() + timedelta(hours=1))
        
        is_blacklisted = await redis_manager.is_token_blacklisted(test_jti)
        if is_blacklisted:
            logger.info("✓ JWT blacklisting working")
        else:
            logger.error("✗ JWT blacklisting failed")
        
        # Get cache statistics
        stats = await redis_manager.get_cache_statistics()
        logger.info(f"Cache statistics: {json.dumps(stats, indent=2)}")
        
        # Cleanup test data
        await redis_manager.delete_session(session_id, "test-user-id")
        await redis_manager.invalidate_user_permissions("test-user-id")
        
        logger.info("Redis authentication cache setup completed successfully!")
        
    except Exception as e:
        logger.error(f"Redis setup failed: {e}")
        raise
    
    finally:
        await redis_manager.close()

if __name__ == "__main__":
    asyncio.run(setup_redis_auth_cache())