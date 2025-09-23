#!/usr/bin/env python3
"""
Crypto Verification Analytics Dashboard
Advanced real-time analytics and machine learning insights
"""

import asyncio
import asyncpg
import numpy as np
import json
import time
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
import logging
from dataclasses import dataclass, asdict

@dataclass
class AnalyticsReport:
    timestamp: datetime
    performance_grade: str
    efficiency_score: float
    trend_direction: str
    predictions: Dict
    recommendations: List[str]
    anomalies: List[str]

class CryptoAnalyticsDashboard:
    def __init__(self):
        self.pool = None
        self.ml_models = {}
        self.analysis_cache = {}
        self.logger = self._setup_logging()

    def _setup_logging(self):
        logging.basicConfig(level=logging.INFO)
        return logging.getLogger('CryptoAnalytics')

    async def initialize(self):
        """Initialize analytics dashboard"""
        try:
            self.pool = await asyncpg.create_pool(
                host='localhost', port=5433, database='claude_agents_auth',
                user='claude_agent', min_size=3, max_size=10
            )
            await self._initialize_ml_models()
            self.logger.info('Analytics dashboard initialized')
            return True
        except Exception as e:
            self.logger.error(f'Dashboard initialization failed: {e}')
            return False

    async def _initialize_ml_models(self):
        """Initialize machine learning models"""
        # Performance prediction model
        self.ml_models['performance_predictor'] = {
            'type': 'linear_regression',
            'weights': np.array([1.2, -0.015, -0.008, 0.1]),
            'bias': 85.0,
            'features': ['time_of_day', 'cpu_usage', 'memory_usage', 'historical_avg']
        }

        # Anomaly detection model
        self.ml_models['anomaly_detector'] = {
            'type': 'statistical',
            'threshold_multiplier': 2.5,
            'window_size': 100
        }

        # Trend analysis model
        self.ml_models['trend_analyzer'] = {
            'type': 'moving_average',
            'short_window': 10,
            'long_window': 50
        }

        self.logger.info('ML models initialized')

    async def generate_comprehensive_report(self) -> AnalyticsReport:
        """Generate comprehensive analytics report"""
        try:
            # Collect recent performance data
            performance_data = await self._collect_performance_data()

            # Analyze performance trends
            trend_analysis = await self._analyze_performance_trends(performance_data)

            # Detect anomalies
            anomalies = await self._detect_anomalies(performance_data)

            # Generate predictions
            predictions = await self._generate_predictions(performance_data)

            # Calculate performance grade
            grade = self._calculate_performance_grade(performance_data)

            # Generate recommendations
            recommendations = await self._generate_recommendations(
                performance_data, trend_analysis, anomalies
            )

            report = AnalyticsReport(
                timestamp=datetime.now(),
                performance_grade=grade['grade'],
                efficiency_score=grade['efficiency'],
                trend_direction=trend_analysis['direction'],
                predictions=predictions,
                recommendations=recommendations,
                anomalies=anomalies
            )

            # Cache the report
            self.analysis_cache['latest_report'] = asdict(report)

            return report

        except Exception as e:
            self.logger.error(f'Report generation failed: {e}')
            return AnalyticsReport(
                datetime.now(), 'ERROR', 0.0, 'unknown', {},
                ['Report generation failed'], ['System error detected']
            )

    async def _collect_performance_data(self) -> List[Dict]:
        """Collect performance data from database"""
        if not self.pool:
            return []

        try:
            async with self.pool.acquire() as conn:
                rows = await conn.fetch('''
                    SELECT
                        timestamp,
                        verifications_per_second,
                        cpu_usage,
                        memory_usage_mb,
                        success_rate,
                        EXTRACT(HOUR FROM timestamp) as hour_of_day
                    FROM crypto_learning.verification_performance
                    WHERE timestamp >= NOW() - INTERVAL '24 hours'
                    ORDER BY timestamp DESC
                    LIMIT 1000
                ''')

                return [dict(row) for row in rows]

        except Exception as e:
            self.logger.error(f'Performance data collection failed: {e}')
            return []

    async def _analyze_performance_trends(self, data: List[Dict]) -> Dict:
        """Analyze performance trends using ML"""
        if len(data) < 10:
            return {'direction': 'insufficient_data', 'confidence': 0.0}

        try:
            # Extract VPS values
            vps_values = [d['verifications_per_second'] for d in data if d['verifications_per_second']]

            if len(vps_values) < 10:
                return {'direction': 'insufficient_data', 'confidence': 0.0}

            # Calculate moving averages
            model = self.ml_models['trend_analyzer']
            short_window = model['short_window']
            long_window = model['long_window']

            if len(vps_values) >= long_window:
                recent_avg = np.mean(vps_values[:short_window])
                historical_avg = np.mean(vps_values[:long_window])

                trend_strength = abs(recent_avg - historical_avg) / historical_avg

                if recent_avg > historical_avg * 1.05:
                    direction = 'improving'
                elif recent_avg < historical_avg * 0.95:
                    direction = 'declining'
                else:
                    direction = 'stable'

                return {
                    'direction': direction,
                    'confidence': min(trend_strength * 2, 1.0),
                    'recent_avg': recent_avg,
                    'historical_avg': historical_avg,
                    'change_percent': ((recent_avg - historical_avg) / historical_avg) * 100
                }

            return {'direction': 'stable', 'confidence': 0.5}

        except Exception as e:
            self.logger.error(f'Trend analysis failed: {e}')
            return {'direction': 'error', 'confidence': 0.0}

    async def _detect_anomalies(self, data: List[Dict]) -> List[str]:
        """Detect performance anomalies"""
        anomalies = []

        if len(data) < 50:
            return anomalies

        try:
            model = self.ml_models['anomaly_detector']
            threshold_mult = model['threshold_multiplier']

            # Check VPS anomalies
            vps_values = [d['verifications_per_second'] for d in data[:100]]
            vps_mean = np.mean(vps_values)
            vps_std = np.std(vps_values)

            recent_vps = vps_values[:10]
            for vps in recent_vps:
                if abs(vps - vps_mean) > threshold_mult * vps_std:
                    anomalies.append(f'VPS anomaly detected: {vps:.1f} (expected ~{vps_mean:.1f})')

            # Check CPU anomalies
            cpu_values = [d['cpu_usage'] for d in data[:100] if d['cpu_usage']]
            if cpu_values:
                cpu_mean = np.mean(cpu_values)
                cpu_std = np.std(cpu_values)

                recent_cpu = cpu_values[:10]
                for cpu in recent_cpu:
                    if abs(cpu - cpu_mean) > threshold_mult * cpu_std:
                        anomalies.append(f'CPU usage anomaly: {cpu:.1f}% (expected ~{cpu_mean:.1f}%)')

            # Check memory anomalies
            memory_values = [d['memory_usage_mb'] for d in data[:100] if d['memory_usage_mb']]
            if memory_values:
                memory_mean = np.mean(memory_values)
                memory_std = np.std(memory_values)

                recent_memory = memory_values[:10]
                for memory in recent_memory:
                    if abs(memory - memory_mean) > threshold_mult * memory_std:
                        anomalies.append(f'Memory anomaly: {memory:.1f}MB (expected ~{memory_mean:.1f}MB)')

        except Exception as e:
            self.logger.error(f'Anomaly detection failed: {e}')
            anomalies.append('Anomaly detection system error')

        return anomalies

    async def _generate_predictions(self, data: List[Dict]) -> Dict:
        """Generate performance predictions"""
        predictions = {}

        if len(data) < 20:
            return {'status': 'insufficient_data'}

        try:
            model = self.ml_models['performance_predictor']

            # Predict next hour performance
            current_time = datetime.now()
            next_hour = current_time.hour + 1 if current_time.hour < 23 else 0

            recent_data = data[:10]
            avg_cpu = np.mean([d['cpu_usage'] for d in recent_data if d['cpu_usage']])
            avg_memory = np.mean([d['memory_usage_mb'] for d in recent_data if d['memory_usage_mb']])
            avg_vps = np.mean([d['verifications_per_second'] for d in recent_data])

            # Simple ML prediction
            features = np.array([next_hour/24, avg_cpu, avg_memory/1000, avg_vps])
            predicted_vps = np.dot(features, model['weights']) + model['bias']
            predicted_vps = max(0, predicted_vps)

            predictions = {
                'next_hour_vps': predicted_vps,
                'confidence': 0.75,
                'trend': 'stable' if abs(predicted_vps - avg_vps) < 5 else ('improving' if predicted_vps > avg_vps else 'declining'),
                'features_used': {
                    'time_factor': next_hour/24,
                    'avg_cpu': avg_cpu,
                    'avg_memory_gb': avg_memory/1000,
                    'current_avg_vps': avg_vps
                }
            }

        except Exception as e:
            self.logger.error(f'Prediction generation failed: {e}')
            predictions = {'status': 'error', 'message': str(e)}

        return predictions

    def _calculate_performance_grade(self, data: List[Dict]) -> Dict:
        """Calculate overall performance grade"""
        if not data:
            return {'grade': 'NO_DATA', 'efficiency': 0.0}

        try:
            recent_data = data[:20]  # Last 20 measurements

            # Calculate metrics
            avg_vps = np.mean([d['verifications_per_second'] for d in recent_data])
            success_rate = np.mean([d['success_rate'] for d in recent_data if d['success_rate']])

            # Calculate efficiency score
            target_vps = 100
            vps_efficiency = min(avg_vps / target_vps, 1.0)
            success_efficiency = success_rate / 100.0 if success_rate else 0.0

            overall_efficiency = (vps_efficiency * 0.7 + success_efficiency * 0.3) * 100

            # Determine grade
            if overall_efficiency >= 90:
                grade = 'EXCELLENT'
            elif overall_efficiency >= 75:
                grade = 'GOOD'
            elif overall_efficiency >= 60:
                grade = 'ACCEPTABLE'
            elif overall_efficiency >= 40:
                grade = 'POOR'
            else:
                grade = 'CRITICAL'

            return {
                'grade': grade,
                'efficiency': overall_efficiency,
                'avg_vps': avg_vps,
                'success_rate': success_rate,
                'target_vps': target_vps
            }

        except Exception as e:
            self.logger.error(f'Grade calculation failed: {e}')
            return {'grade': 'ERROR', 'efficiency': 0.0}

    async def _generate_recommendations(self, data: List[Dict], trends: Dict, anomalies: List[str]) -> List[str]:
        """Generate optimization recommendations"""
        recommendations = []

        if not data:
            return ['Insufficient data for recommendations']

        try:
            recent_data = data[:20]
            avg_vps = np.mean([d['verifications_per_second'] for d in recent_data])
            avg_cpu = np.mean([d['cpu_usage'] for d in recent_data if d['cpu_usage']])
            avg_memory = np.mean([d['memory_usage_mb'] for d in recent_data if d['memory_usage_mb']])

            # Performance recommendations
            if avg_vps < 80:
                recommendations.append('Performance below optimal - consider system tuning')

            if avg_cpu > 85:
                recommendations.append('High CPU usage detected - consider load balancing or optimization')

            if avg_memory > 800:
                recommendations.append('High memory usage - review memory allocation and buffer sizes')

            # Trend-based recommendations
            if trends.get('direction') == 'declining':
                recommendations.append('Performance declining - investigate recent system changes')

            # Anomaly-based recommendations
            if anomalies:
                recommendations.append('Performance anomalies detected - review system stability')

            # Time-based recommendations
            current_hour = datetime.now().hour
            if 9 <= current_hour <= 17:  # Business hours
                recommendations.append('Consider scheduling intensive operations outside business hours')

            # Success rate recommendations
            success_rates = [d['success_rate'] for d in recent_data if d['success_rate']]
            if success_rates and np.mean(success_rates) < 95:
                recommendations.append('Low success rate - investigate crypto verification failures')

            if not recommendations:
                recommendations.append('System performing optimally - no immediate actions needed')

        except Exception as e:
            self.logger.error(f'Recommendation generation failed: {e}')
            recommendations = ['Error generating recommendations']

        return recommendations

    async def export_analytics_data(self, format_type: str = 'json') -> str:
        """Export analytics data in specified format"""
        try:
            report = await self.generate_comprehensive_report()

            if format_type == 'json':
                return json.dumps(asdict(report), indent=2, default=str)
            elif format_type == 'summary':
                efficiency_text = f'{report.efficiency_score:.1f}%'
                return f'''
Crypto Verification Analytics Summary
====================================
Timestamp: {report.timestamp}
Performance Grade: {report.performance_grade}
Efficiency Score: {efficiency_text}
Trend Direction: {report.trend_direction}

Predictions:
{json.dumps(report.predictions, indent=2, default=str)}

Recommendations:
{chr(10).join(f'• {rec}' for rec in report.recommendations)}

Anomalies:
{chr(10).join(f'⚠ {anom}' for anom in report.anomalies) if report.anomalies else 'None detected'}
'''
        except Exception as e:
            self.logger.error(f'Export failed: {e}')
            return f'Export error: {e}'

async def main():
    dashboard = CryptoAnalyticsDashboard()

    if await dashboard.initialize():
        print('Generating crypto analytics report...')
        report = await dashboard.generate_comprehensive_report()

        print('\n' + '='*60)
        print(await dashboard.export_analytics_data('summary'))
        print('='*60)

        return 0
    else:
        print('Failed to initialize analytics dashboard')
        return 1

if __name__ == '__main__':
    exit(asyncio.run(main()))