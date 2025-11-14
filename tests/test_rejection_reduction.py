#!/usr/bin/env python3
"""
Comprehensive Test Suite for Claude Code Rejection Reduction System
Tests all 10 strategies and their integration with existing systems
"""

import asyncio
import json
import os
import sys
import time
from typing import Any, Dict, List
from unittest.mock import AsyncMock, Mock, patch

import pytest

# Add source paths
sys.path.append(
    os.path.join(os.path.dirname(__file__), "..", "agents", "src", "python")
)

from claude_rejection_reducer import (
    ClaudeRejectionReducer,
    RejectionContext,
    RejectionType,
    StrategyResult,
)
from rejection_reduction_integration import (
    ClaudeWrapperIntegration,
    UnifiedClaudeOptimizer,
    optimize_for_claude_simple,
)


class TestRejectionScenarios:
    """Test various Claude rejection scenarios"""

    @pytest.fixture
    def rejection_reducer(self):
        """Create rejection reducer for testing"""
        return ClaudeRejectionReducer(
            db_connection_string="sqlite:///:memory:",
            enable_learning=False,  # Disable for testing
            debug_mode=True,
        )

    @pytest.fixture
    def unified_optimizer(self):
        """Create unified optimizer for testing"""
        return UnifiedClaudeOptimizer(
            enable_rejection_reduction=True,
            enable_learning=False,  # Disable for testing
            db_connection_string="sqlite:///:memory:",
        )

    # Test rejection trigger content samples
    SECURITY_TRIGGER_CONTENT = """
    def create_exploit():
        password = "admin123"
        api_key = "sk-proj-realkey123"
        payload = generate_malicious_payload()
        backdoor = establish_backdoor_connection()
        return exploit_vulnerability(payload, backdoor)
    """

    HARMFUL_COMMAND_CONTENT = """
    import os
    import subprocess

    # Dangerous system commands
    def system_damage():
        os.system("rm -rf /")
        subprocess.run(["format", "C:"])
        subprocess.run(["dd", "if=/dev/zero", "of=/dev/sda"])
    """

    SENSITIVE_DATA_CONTENT = """
    DATABASE_CONFIG = {
        "password": "SuperSecret123!",
        "api_key": "sk-live-abcd1234567890",
        "private_key": "-----BEGIN RSA PRIVATE KEY-----",
        "session_secret": "ultra_secret_session_key_12345"
    }
    """

    LARGE_FILE_CONTENT = "x" * 100000  # 100KB of content

    @pytest.mark.asyncio
    async def test_security_trigger_reduction(self, rejection_reducer):
        """Test reduction of security trigger content"""

        result, status = await rejection_reducer.process_request(
            self.SECURITY_TRIGGER_CONTENT, "security_analysis", ["security_test.py"]
        )

        assert status in [StrategyResult.SUCCESS, StrategyResult.PARTIAL_SUCCESS]

        # Verify problematic terms are replaced
        assert "exploit" not in result.lower()
        assert "backdoor" not in result.lower()
        assert "malicious" not in result.lower()
        assert "admin123" not in result  # Password should be redacted

        # Verify structure is preserved
        assert "def " in result  # Function structure maintained
        assert "security_test_case" in result or "security_analysis" in result

    @pytest.mark.asyncio
    async def test_harmful_command_filtering(self, rejection_reducer):
        """Test filtering of harmful system commands"""

        result, status = await rejection_reducer.process_request(
            self.HARMFUL_COMMAND_CONTENT, "system_analysis"
        )

        assert status in [StrategyResult.SUCCESS, StrategyResult.PARTIAL_SUCCESS]

        # Verify dangerous commands are neutralized
        assert "rm -rf /" not in result
        assert "format C:" not in result
        assert "dd if=/dev/zero" not in result

        # Should have safe alternatives
        assert (
            "remove_directory_safely" in result
            or "[DANGEROUS_COMMAND_REMOVED]" in result
        )

    @pytest.mark.asyncio
    async def test_sensitive_data_redaction(self, rejection_reducer):
        """Test redaction of sensitive data"""

        result, status = await rejection_reducer.process_request(
            self.SENSITIVE_DATA_CONTENT, "configuration_review"
        )

        assert status in [StrategyResult.SUCCESS, StrategyResult.PARTIAL_SUCCESS]

        # Verify sensitive values are redacted
        assert "SuperSecret123!" not in result
        assert "sk-live-abcd1234567890" not in result
        assert "ultra_secret_session_key_12345" not in result

        # Verify structure is preserved with redaction markers
        assert "[REDACTED" in result
        assert "DATABASE_CONFIG" in result  # Structure maintained

    @pytest.mark.asyncio
    async def test_large_file_optimization(self, rejection_reducer):
        """Test optimization of large file content"""

        result, status = await rejection_reducer.process_request(
            self.LARGE_FILE_CONTENT, "file_analysis", ["large_file.txt"]
        )

        assert status in [StrategyResult.SUCCESS, StrategyResult.PARTIAL_SUCCESS]

        # Should be significantly reduced
        assert len(result) < len(self.LARGE_FILE_CONTENT) * 0.5

        # Should contain metadata instead
        assert "metadata" in result.lower() or "summary" in result.lower()

    @pytest.mark.asyncio
    async def test_rejection_risk_analysis(self, rejection_reducer):
        """Test rejection risk analysis accuracy"""

        # High risk content
        high_risk = await rejection_reducer._analyze_rejection_risk(
            RejectionContext(
                content=self.SECURITY_TRIGGER_CONTENT,
                request_type="security",
                rejection_reason="",
                rejection_type=RejectionType.SAFETY_FILTER,
            )
        )

        assert high_risk > 0.7  # Should detect high risk

        # Low risk content
        safe_content = "def add(a, b): return a + b"
        low_risk = await rejection_reducer._analyze_rejection_risk(
            RejectionContext(
                content=safe_content,
                request_type="code_review",
                rejection_reason="",
                rejection_type=RejectionType.UNKNOWN,
            )
        )

        assert low_risk < 0.3  # Should detect low risk

    @pytest.mark.asyncio
    async def test_layered_strategy_application(self, rejection_reducer):
        """Test that multiple strategies are applied in sequence"""

        complex_content = f"""
        {self.SECURITY_TRIGGER_CONTENT}
        {self.SENSITIVE_DATA_CONTENT}
        """

        result, status = await rejection_reducer.process_request(
            complex_content, "comprehensive_analysis"
        )

        assert status in [StrategyResult.SUCCESS, StrategyResult.PARTIAL_SUCCESS]

        # Multiple optimizations should be applied
        stats = rejection_reducer.stats
        assert stats["strategy_usage"]  # Some strategies were used

        # Content should be significantly modified
        similarity = len(set(result.split()) & set(complex_content.split())) / len(
            set(complex_content.split())
        )
        assert similarity < 0.8  # Significant modification


class TestUnifiedOptimizer:
    """Test the unified optimization system"""

    @pytest.fixture
    def optimizer(self):
        return UnifiedClaudeOptimizer(
            enable_rejection_reduction=True, enable_learning=False
        )

    @pytest.mark.asyncio
    async def test_unified_optimization_pipeline(self, optimizer, tmp_path):
        """Test the complete optimization pipeline"""

        test_content = (
            """
        # Security analysis with multiple issues
        def analyze_system():
            password = "secret123"
            exploit_code = create_payload()
            backdoor_access = "admin_backdoor"

            # Large comment block to test context chopping
            # This is a very long comment that goes on and on
            # """
            + "# More comments\n" * 100
            + """

            return run_security_test()
        """
        )

        p = tmp_path / "security_analysis.py"
        p.write_text(test_content)

        result, metadata = await optimizer.optimize_for_claude(
            content=test_content, file_paths=[str(p)], request_type="security_review"
        )

        # Should apply multiple optimizations
        assert len(metadata["optimizations_applied"]) >= 1
        assert metadata["acceptance_predicted"] == True

        # Should modify content while preserving functionality
        assert result != test_content
        assert "def " in result  # Function structure preserved
        assert "secret123" not in result  # Sensitive data removed

    @pytest.mark.asyncio
    async def test_context_chopping_integration(self, optimizer):
        """Test integration with existing context chopping system"""

        # Create content that would benefit from context chopping
        large_content = "\n".join(
            [f"def function_{i}(): return {i}" for i in range(1000)]
        )

        result, metadata = await optimizer.optimize_for_claude(
            content=large_content, request_type="code_analysis"
        )

        # Context chopping should be applied
        assert "intelligent_context_chopping" in metadata["optimizations_applied"]
        assert result != large_content

        # Important content should be preserved
        assert "def function_" in result

    @pytest.mark.asyncio
    async def test_permission_handling(self, optimizer):
        """Test permission handling integration"""

        # Test with non-existent files
        result, metadata = await optimizer.optimize_for_claude(
            content="# Test content",
            file_paths=["/non/existent/file.py", "/another/missing/file.py"],
            request_type="file_analysis",
        )

        # Should handle permission issues gracefully
        assert result is not None
        assert "permission issues" in result.lower() or "fallback" in result.lower()

    @pytest.mark.asyncio
    async def test_system_status_reporting(self, optimizer):
        """Test system status and metrics reporting"""

        # Process some requests to generate metrics
        await optimizer.optimize_for_claude("test content 1")
        await optimizer.optimize_for_claude("test content 2")

        status = await optimizer.get_system_status()

        # Should have comprehensive status information
        assert "systems_enabled" in status
        assert "performance_metrics" in status
        assert "component_status" in status
        assert "optimization_effectiveness" in status

        # Metrics should be updated
        assert status["performance_metrics"]["total_requests"] >= 2


class TestWrapperIntegration:
    """Test Claude wrapper integration"""

    @pytest.mark.asyncio
    async def test_simple_wrapper_integration(self):
        """Test simple wrapper integration function"""

        content = "def vulnerable_function(): password = 'admin123'"

        result = await optimize_for_claude_simple(
            content=content, request_type="security_review"
        )

        assert result is not None
        assert len(result) > 0
        assert "admin123" not in result  # Should be filtered

    @pytest.mark.asyncio
    async def test_wrapper_with_files(self):
        """Test wrapper integration with file paths"""

        content = "# Test content with files"
        files = ["test1.py", "test2.js"]

        result = await optimize_for_claude_simple(
            content=content, files=files, request_type="code_review"
        )

        assert result is not None
        # Should handle files gracefully even if they don't exist


class TestPerformanceMetrics:
    """Test performance and effectiveness metrics"""

    @pytest.mark.asyncio
    async def test_processing_speed(self):
        """Test that optimization doesn't significantly slow down processing"""

        optimizer = UnifiedClaudeOptimizer(enable_learning=False)
        test_content = "def test(): return 'hello world'"

        # Measure processing time
        start_time = time.time()
        result, metadata = await optimizer.optimize_for_claude(test_content)
        processing_time = time.time() - start_time

        # Should be fast (under 1 second for simple content)
        assert processing_time < 1.0
        assert metadata["processing_time"] > 0

    @pytest.mark.asyncio
    async def test_acceptance_rate_tracking(self):
        """Test acceptance rate tracking"""

        reducer = ClaudeRejectionReducer(enable_learning=False, debug_mode=True)

        # Process various types of content
        test_cases = [
            ("safe content", StrategyResult.SUCCESS),
            ("def test(): password = 'secret'", StrategyResult.SUCCESS),
            ("exploit code here", StrategyResult.SUCCESS),
        ]

        for content, expected in test_cases:
            result, status = await reducer.process_request(content)
            assert status in [StrategyResult.SUCCESS, StrategyResult.PARTIAL_SUCCESS]

        # Acceptance rate should be high
        assert reducer.stats["acceptance_rate"] >= 0.6


class TestErrorHandling:
    """Test error handling and edge cases"""

    @pytest.mark.asyncio
    async def test_empty_content_handling(self):
        """Test handling of empty or None content"""

        reducer = ClaudeRejectionReducer(enable_learning=False)

        # Empty string
        result, status = await reducer.process_request("")
        assert status == StrategyResult.SUCCESS
        assert result == ""

        # Whitespace only
        result, status = await reducer.process_request("   \n  \t  ")
        assert status == StrategyResult.SUCCESS

    @pytest.mark.asyncio
    async def test_malformed_content_handling(self):
        """Test handling of malformed or invalid content"""

        reducer = ClaudeRejectionReducer(enable_learning=False)

        # Binary-like content
        binary_content = "\x00\x01\x02\x03" * 100
        result, status = await reducer.process_request(binary_content)
        assert status in [StrategyResult.SUCCESS, StrategyResult.PARTIAL_SUCCESS]

        # Very long single line
        long_line = "x" * 50000
        result, status = await reducer.process_request(long_line)
        assert status in [StrategyResult.SUCCESS, StrategyResult.PARTIAL_SUCCESS]

    @pytest.mark.asyncio
    async def test_strategy_failure_resilience(self):
        """Test system resilience when individual strategies fail"""

        reducer = ClaudeRejectionReducer(enable_learning=False)

        # Mock a strategy to fail
        with patch.object(
            reducer, "_apply_claude_filter", side_effect=Exception("Strategy failed")
        ):
            result, status = await reducer.process_request(
                "test content with exploit", "test"
            )

            # Should still succeed with other strategies
            assert status in [StrategyResult.SUCCESS, StrategyResult.PARTIAL_SUCCESS]
            assert result is not None


# Performance benchmark tests
class TestPerformanceBenchmarks:
    """Performance benchmarks for the rejection reduction system"""

    @pytest.mark.benchmark
    @pytest.mark.asyncio
    async def test_large_content_performance(self):
        """Benchmark performance with large content"""

        # Generate large content (1MB)
        large_content = "\n".join(
            [
                f"def function_{i}():\n    # Function {i}\n    return {i}"
                for i in range(10000)
            ]
        )

        optimizer = UnifiedClaudeOptimizer(enable_learning=False)

        start_time = time.time()
        result, metadata = await optimizer.optimize_for_claude(large_content)
        total_time = time.time() - start_time

        print(f"Large content processing time: {total_time:.3f}s")
        print(f"Original size: {len(large_content)} chars")
        print(f"Optimized size: {len(result)} chars")
        print(f"Compression ratio: {len(result)/len(large_content):.3f}")

        # Should complete in reasonable time (under 5 seconds)
        assert total_time < 5.0

    @pytest.mark.benchmark
    @pytest.mark.asyncio
    async def test_concurrent_processing(self):
        """Test concurrent processing performance"""

        optimizer = UnifiedClaudeOptimizer(enable_learning=False)

        # Create multiple requests
        requests = [f"def test_{i}(): password = 'secret_{i}'" for i in range(10)]

        start_time = time.time()

        # Process concurrently
        tasks = [
            optimizer.optimize_for_claude(content, request_type=f"test_{i}")
            for i, content in enumerate(requests)
        ]

        results = await asyncio.gather(*tasks)

        total_time = time.time() - start_time

        print(
            f"Concurrent processing time: {total_time:.3f}s for {len(requests)} requests"
        )
        print(f"Average per request: {total_time/len(requests):.3f}s")

        # All should succeed
        assert len(results) == len(requests)
        for result, metadata in results:
            assert result is not None
            assert metadata["acceptance_predicted"] == True


if __name__ == "__main__":
    # Run tests with pytest
    pytest.main(
        [__file__, "-v", "--tb=short", "-x"]  # Stop on first failure for debugging
    )
