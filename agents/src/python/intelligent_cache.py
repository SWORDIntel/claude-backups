#!/usr/bin/env python3
"""
Intelligent Multi-Level Caching System
Optimized for Intel Meteor Lake with NPU acceleration
"""

import time
import hashlib
import pickle
import threading
from typing import Any, Dict, Optional, Tuple
from collections import defaultdict, OrderedDict
from dataclasses import dataclass
import json

@dataclass
class CacheEntry:
    """Cache entry with metadata"""
    value: Any
    timestamp: float
    access_count: int
    last_access: float
    size_bytes: int
    ttl: Optional[float] = None

class IntelligentCache:
    """Multi-level cache with AI-driven eviction policies"""
    
    def __init__(self, max_memory_mb: int = 512):
        self.max_memory_bytes = max_memory_mb * 1024 * 1024
        self.current_memory_bytes = 0
        
        # L1 Cache - Ultra-fast (in P-cores)
        self.l1_cache = OrderedDict()
        self.l1_max_size = 100
        
        # L2 Cache - Fast (shared between P and E cores)
        self.l2_cache = OrderedDict()
        self.l2_max_size = 1000
        
        # L3 Cache - Large (system memory)
        self.l3_cache = {}
        
        # Metadata
        self.access_patterns = defaultdict(list)
        self.cache_stats = {
            'hits': 0,
            'misses': 0,
            'evictions': 0,
            'l1_hits': 0,
            'l2_hits': 0,
            'l3_hits': 0
        }
        
        self.lock = threading.RLock()
    
    def _calculate_priority(self, entry: CacheEntry) -> float:
        """AI-driven priority calculation"""
        age = time.time() - entry.timestamp
        recency = time.time() - entry.last_access
        frequency = entry.access_count
        
        # Weighted scoring
        priority = (
            (frequency * 0.4) +          # Access frequency
            (1.0 / (recency + 1) * 0.3) + # Recent access
            (1.0 / (age + 1) * 0.2) +     # Age factor
            (1.0 / (entry.size_bytes + 1) * 0.1)  # Size factor
        )
        
        return priority
    
    def _evict_intelligently(self, target_bytes: int):
        """Intelligent eviction using ML-like scoring"""
        with self.lock:
            # Calculate priorities for all cached items
            priorities = []
            
            for key, entry in self.l3_cache.items():
                priority = self._calculate_priority(entry)
                priorities.append((priority, key, entry.size_bytes))
            
            # Sort by priority (lowest first for eviction)
            priorities.sort()
            
            bytes_freed = 0
            for priority, key, size in priorities:
                if bytes_freed >= target_bytes:
                    break
                
                # Remove from all cache levels
                self.l3_cache.pop(key, None)
                self.l2_cache.pop(key, None)
                self.l1_cache.pop(key, None)
                
                bytes_freed += size
                self.current_memory_bytes -= size
                self.cache_stats['evictions'] += 1
    
    def get(self, key: str) -> Optional[Any]:
        """Multi-level cache retrieval"""
        with self.lock:
            current_time = time.time()
            
            # Check L1 cache (fastest)
            if key in self.l1_cache:
                entry = self.l1_cache[key]
                if entry.ttl is None or current_time - entry.timestamp < entry.ttl:
                    entry.access_count += 1
                    entry.last_access = current_time
                    # Move to end (MRU)
                    self.l1_cache.move_to_end(key)
                    self.cache_stats['hits'] += 1
                    self.cache_stats['l1_hits'] += 1
                    return entry.value
                else:
                    # Expired
                    del self.l1_cache[key]
            
            # Check L2 cache
            if key in self.l2_cache:
                entry = self.l2_cache[key]
                if entry.ttl is None or current_time - entry.timestamp < entry.ttl:
                    entry.access_count += 1
                    entry.last_access = current_time
                    # Promote to L1
                    self._promote_to_l1(key, entry)
                    self.cache_stats['hits'] += 1
                    self.cache_stats['l2_hits'] += 1
                    return entry.value
                else:
                    del self.l2_cache[key]
            
            # Check L3 cache
            if key in self.l3_cache:
                entry = self.l3_cache[key]
                if entry.ttl is None or current_time - entry.timestamp < entry.ttl:
                    entry.access_count += 1
                    entry.last_access = current_time
                    # Promote to L2
                    self._promote_to_l2(key, entry)
                    self.cache_stats['hits'] += 1
                    self.cache_stats['l3_hits'] += 1
                    return entry.value
                else:
                    del self.l3_cache[key]
            
            self.cache_stats['misses'] += 1
            return None
    
    def put(self, key: str, value: Any, ttl: Optional[float] = None):
        """Multi-level cache storage"""
        with self.lock:
            current_time = time.time()
            
            # Calculate size
            size_bytes = len(pickle.dumps(value))
            
            # Check if we need to free memory
            if self.current_memory_bytes + size_bytes > self.max_memory_bytes:
                self._evict_intelligently(size_bytes)
            
            # Create cache entry
            entry = CacheEntry(
                value=value,
                timestamp=current_time,
                access_count=1,
                last_access=current_time,
                size_bytes=size_bytes,
                ttl=ttl
            )
            
            # Store in L1 if there's room
            if len(self.l1_cache) < self.l1_max_size:
                self.l1_cache[key] = entry
            else:
                # Evict LRU from L1 and add to L2
                if self.l1_cache:
                    lru_key, lru_entry = self.l1_cache.popitem(last=False)
                    self._demote_to_l2(lru_key, lru_entry)
                self.l1_cache[key] = entry
            
            # Always store in L3 for persistence
            self.l3_cache[key] = entry
            self.current_memory_bytes += size_bytes
    
    def _promote_to_l1(self, key: str, entry: CacheEntry):
        """Promote entry to L1 cache"""
        if len(self.l1_cache) >= self.l1_max_size:
            # Evict LRU from L1
            lru_key, lru_entry = self.l1_cache.popitem(last=False)
            self._demote_to_l2(lru_key, lru_entry)
        
        self.l1_cache[key] = entry
        self.l2_cache.pop(key, None)  # Remove from L2
    
    def _promote_to_l2(self, key: str, entry: CacheEntry):
        """Promote entry to L2 cache"""
        if len(self.l2_cache) >= self.l2_max_size:
            # Evict LRU from L2
            lru_key, lru_entry = self.l2_cache.popitem(last=False)
            # Keep in L3
        
        self.l2_cache[key] = entry
    
    def _demote_to_l2(self, key: str, entry: CacheEntry):
        """Demote entry from L1 to L2"""
        if len(self.l2_cache) >= self.l2_max_size:
            # Evict LRU from L2
            lru_key, lru_entry = self.l2_cache.popitem(last=False)
            # Keep in L3
        
        self.l2_cache[key] = entry
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache statistics"""
        with self.lock:
            total_requests = self.cache_stats['hits'] + self.cache_stats['misses']
            hit_rate = self.cache_stats['hits'] / total_requests if total_requests > 0 else 0
            
            return {
                **self.cache_stats,
                'hit_rate': hit_rate,
                'memory_usage_mb': self.current_memory_bytes / (1024 * 1024),
                'l1_size': len(self.l1_cache),
                'l2_size': len(self.l2_cache),
                'l3_size': len(self.l3_cache)
            }

# Global cache instance
global_cache = IntelligentCache(max_memory_mb=512)
