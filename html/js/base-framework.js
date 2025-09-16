/**
 * Claude Agent Framework - HTML Documentation Base JavaScript Framework
 * Professional interactive features matching SHADOWGIT.html standards
 */

class ClaudeFramework {
    constructor() {
        this.modules = new Map();
        this.metrics = new Map();
        this.animations = new Map();
        this.init();
    }

    init() {
        this.setupEventListeners();
        this.initializeAnimations();
        this.loadMetrics();
        this.setupNavigation();
        this.initializeTooltips();
        console.log('🚀 Claude Framework initialized');
    }

    setupEventListeners() {
        // Performance card hover effects
        document.querySelectorAll('.metric-card').forEach(card => {
            card.addEventListener('mouseenter', this.animateMetricCard.bind(this));
            card.addEventListener('mouseleave', this.resetMetricCard.bind(this));
        });

        // Module card interactions
        document.querySelectorAll('.module-card').forEach(card => {
            card.addEventListener('click', this.handleModuleClick.bind(this));
        });

        // Smooth scrolling for navigation
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', this.smoothScroll.bind(this));
        });

        // Keyboard navigation
        document.addEventListener('keydown', this.handleKeyboard.bind(this));
    }

    initializeAnimations() {
        // Performance indicators glow animation
        this.startPerformanceGlow();

        // Stagger fade-in animations for cards
        this.staggerFadeIn('.module-card', 100);
        this.staggerFadeIn('.metric-card', 50);
    }

    startPerformanceGlow() {
        const indicators = document.querySelectorAll('.performance-indicator');
        indicators.forEach((indicator, index) => {
            indicator.style.animationDelay = `${index * 0.5}s`;
            indicator.classList.add('glow');
        });
    }

    staggerFadeIn(selector, delay) {
        const elements = document.querySelectorAll(selector);
        elements.forEach((element, index) => {
            element.style.opacity = '0';
            element.style.transform = 'translateY(20px)';

            setTimeout(() => {
                element.style.transition = 'all 0.6s ease-out';
                element.style.opacity = '1';
                element.style.transform = 'translateY(0)';
            }, index * delay);
        });
    }

    animateMetricCard(event) {
        const card = event.currentTarget;
        const value = card.querySelector('.metric-value');

        card.style.transform = 'translateY(-5px) scale(1.02)';
        card.style.boxShadow = '0 10px 30px rgba(0, 255, 136, 0.3)';

        if (value) {
            value.style.textShadow = '0 0 20px currentColor';
            this.animateCountUp(value);
        }
    }

    resetMetricCard(event) {
        const card = event.currentTarget;
        card.style.transform = 'translateY(0) scale(1)';
        card.style.boxShadow = '';

        const value = card.querySelector('.metric-value');
        if (value) {
            value.style.textShadow = '';
        }
    }

    animateCountUp(element) {
        const finalValue = element.textContent;
        const numericValue = parseFloat(finalValue);

        if (isNaN(numericValue)) return;

        const duration = 800;
        const steps = 30;
        const increment = numericValue / steps;
        let currentValue = 0;
        let step = 0;

        const timer = setInterval(() => {
            currentValue += increment;
            step++;

            if (step >= steps) {
                element.textContent = finalValue;
                clearInterval(timer);
            } else {
                const suffix = finalValue.replace(/[\d.]/g, '');
                const prefix = finalValue.match(/^[^\d]*/)[0];
                element.textContent = prefix + currentValue.toFixed(1) + suffix;
            }
        }, duration / steps);
    }

    handleModuleClick(event) {
        const card = event.currentTarget;
        const moduleId = card.dataset.moduleId;

        if (moduleId) {
            this.highlightModule(moduleId);
            this.loadModuleDetails(moduleId);
        }
    }

    highlightModule(moduleId) {
        // Remove previous highlights
        document.querySelectorAll('.module-card').forEach(card => {
            card.classList.remove('module-highlighted');
        });

        // Add highlight to selected module
        const selectedCard = document.querySelector(`[data-module-id="${moduleId}"]`);
        if (selectedCard) {
            selectedCard.classList.add('module-highlighted');

            // Add temporary glow effect
            selectedCard.style.boxShadow = '0 0 30px rgba(0, 212, 255, 0.5)';

            setTimeout(() => {
                selectedCard.style.boxShadow = '';
            }, 2000);
        }
    }

    loadModuleDetails(moduleId) {
        const moduleData = this.modules.get(moduleId);
        if (moduleData) {
            this.showModuleModal(moduleData);
        } else {
            // Simulate loading module details
            this.showLoadingIndicator();

            setTimeout(() => {
                this.hideLoadingIndicator();
                console.log(`📊 Loading details for module: ${moduleId}`);
            }, 500);
        }
    }

    showModuleModal(moduleData) {
        // Create modal overlay
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay';
        overlay.innerHTML = `
            <div class="modal-content">
                <div class="modal-header">
                    <h3>${moduleData.title}</h3>
                    <button class="modal-close">&times;</button>
                </div>
                <div class="modal-body">
                    <p>${moduleData.description}</p>
                    ${moduleData.details || ''}
                </div>
            </div>
        `;

        document.body.appendChild(overlay);

        // Close modal handlers
        overlay.querySelector('.modal-close').onclick = () => {
            document.body.removeChild(overlay);
        };

        overlay.onclick = (e) => {
            if (e.target === overlay) {
                document.body.removeChild(overlay);
            }
        };
    }

    smoothScroll(event) {
        event.preventDefault();
        const targetId = event.currentTarget.getAttribute('href');
        const targetElement = document.querySelector(targetId);

        if (targetElement) {
            targetElement.scrollIntoView({
                behavior: 'smooth',
                block: 'start'
            });
        }
    }

    handleKeyboard(event) {
        // ESC key to close modals
        if (event.key === 'Escape') {
            const modal = document.querySelector('.modal-overlay');
            if (modal) {
                document.body.removeChild(modal);
            }
        }

        // Navigation with arrow keys
        if (event.ctrlKey) {
            switch(event.key) {
                case 'ArrowRight':
                    this.navigateNext();
                    break;
                case 'ArrowLeft':
                    this.navigatePrevious();
                    break;
            }
        }
    }

    setupNavigation() {
        // Highlight active navigation item
        const currentPath = window.location.pathname;
        document.querySelectorAll('.nav-menu a').forEach(link => {
            if (link.pathname === currentPath) {
                link.classList.add('active');
            }
        });

        // Mobile menu toggle
        this.setupMobileMenu();
    }

    setupMobileMenu() {
        const menuToggle = document.querySelector('.menu-toggle');
        const navMenu = document.querySelector('.nav-menu');

        if (menuToggle && navMenu) {
            menuToggle.addEventListener('click', () => {
                navMenu.classList.toggle('nav-menu-open');
            });
        }
    }

    initializeTooltips() {
        document.querySelectorAll('[data-tooltip]').forEach(element => {
            element.addEventListener('mouseenter', this.showTooltip.bind(this));
            element.addEventListener('mouseleave', this.hideTooltip.bind(this));
        });
    }

    showTooltip(event) {
        const element = event.currentTarget;
        const tooltipText = element.dataset.tooltip;

        const tooltip = document.createElement('div');
        tooltip.className = 'tooltip';
        tooltip.textContent = tooltipText;
        document.body.appendChild(tooltip);

        const rect = element.getBoundingClientRect();
        tooltip.style.left = rect.left + (rect.width / 2) + 'px';
        tooltip.style.top = rect.top - 35 + 'px';

        element._tooltip = tooltip;
    }

    hideTooltip(event) {
        const element = event.currentTarget;
        if (element._tooltip) {
            document.body.removeChild(element._tooltip);
            delete element._tooltip;
        }
    }

    loadMetrics() {
        // Simulate real-time metrics updates
        this.updateMetrics();
        setInterval(() => this.updateMetrics(), 5000);
    }

    updateMetrics() {
        const metricCards = document.querySelectorAll('.metric-card');
        metricCards.forEach(card => {
            const value = card.querySelector('.metric-value');
            const label = card.querySelector('.metric-label');

            if (value && label) {
                // Add subtle animation for live updates
                value.style.transition = 'color 0.3s ease';
                value.style.color = 'var(--neon-blue)';

                setTimeout(() => {
                    value.style.color = 'var(--neon-green)';
                }, 300);
            }
        });
    }

    showLoadingIndicator() {
        const loader = document.createElement('div');
        loader.className = 'loading-indicator';
        loader.innerHTML = `
            <div class="loading-spinner"></div>
            <span>Loading module details...</span>
        `;
        document.body.appendChild(loader);
    }

    hideLoadingIndicator() {
        const loader = document.querySelector('.loading-indicator');
        if (loader) {
            document.body.removeChild(loader);
        }
    }

    // Public API methods
    registerModule(id, data) {
        this.modules.set(id, data);
    }

    updateMetric(id, value) {
        this.metrics.set(id, value);
        const element = document.querySelector(`[data-metric-id="${id}"] .metric-value`);
        if (element) {
            element.textContent = value;
            this.animateCountUp(element);
        }
    }

    navigateNext() {
        const activeLink = document.querySelector('.nav-menu a.active');
        const nextLink = activeLink?.parentElement?.nextElementSibling?.querySelector('a');
        if (nextLink) {
            window.location.href = nextLink.href;
        }
    }

    navigatePrevious() {
        const activeLink = document.querySelector('.nav-menu a.active');
        const prevLink = activeLink?.parentElement?.previousElementSibling?.querySelector('a');
        if (prevLink) {
            window.location.href = prevLink.href;
        }
    }
}

// Performance monitoring utilities
class PerformanceMonitor {
    constructor() {
        this.metrics = {};
        this.startTime = performance.now();
    }

    mark(name) {
        this.metrics[name] = performance.now() - this.startTime;
    }

    measure(name, startMark, endMark) {
        if (this.metrics[startMark] && this.metrics[endMark]) {
            return this.metrics[endMark] - this.metrics[startMark];
        }
        return 0;
    }

    report() {
        console.table(this.metrics);
    }
}

// Real-time data integration
class DataIntegration {
    constructor() {
        this.endpoints = new Map();
        this.updateInterval = 5000;
    }

    registerEndpoint(name, url, transformer = null) {
        this.endpoints.set(name, { url, transformer });
    }

    async fetchData(endpointName) {
        const endpoint = this.endpoints.get(endpointName);
        if (!endpoint) return null;

        try {
            const response = await fetch(endpoint.url);
            const data = await response.json();
            return endpoint.transformer ? endpoint.transformer(data) : data;
        } catch (error) {
            console.warn(`Failed to fetch data from ${endpointName}:`, error);
            return null;
        }
    }

    startRealTimeUpdates() {
        setInterval(async () => {
            for (const [name] of this.endpoints) {
                const data = await this.fetchData(name);
                if (data) {
                    this.updateDisplay(name, data);
                }
            }
        }, this.updateInterval);
    }

    updateDisplay(endpointName, data) {
        const event = new CustomEvent('dataUpdate', {
            detail: { endpoint: endpointName, data }
        });
        document.dispatchEvent(event);
    }
}

// Initialize framework when DOM is ready
let claudeFramework;
let performanceMonitor;
let dataIntegration;

document.addEventListener('DOMContentLoaded', () => {
    performanceMonitor = new PerformanceMonitor();
    performanceMonitor.mark('framework-init-start');

    claudeFramework = new ClaudeFramework();
    dataIntegration = new DataIntegration();

    performanceMonitor.mark('framework-init-end');

    // Global error handling
    window.addEventListener('error', (event) => {
        console.error('Framework error:', event.error);
    });

    // Global data update listener
    document.addEventListener('dataUpdate', (event) => {
        console.log('📊 Data update received:', event.detail);
    });
});

// Export for use in modules
window.ClaudeFramework = {
    instance: () => claudeFramework,
    performance: () => performanceMonitor,
    data: () => dataIntegration
};