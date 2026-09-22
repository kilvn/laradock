FROM ccr.ccs.tencentyun.com/workbuddy/server:latest

# Install Playwright + Chromium dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 \
    libcups2 libxkbcommon0 libxcomposite1 libxdamage1 \
    libxrandr2 libgbm1 libpango-1.0-0 libcairo2 \
    libasound2 libatspi2.0-0 libxshmfence1 \
    && rm -rf /var/lib/apt/lists/*

# Install Playwright and download Chromium
RUN python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install playwright \
    && /opt/venv/bin/playwright install chromium \
    && /opt/venv/bin/playwright install-deps chromium

ENV PATH="/opt/venv/bin:$PATH"
ENV PLAYWRIGHT_BROWSERS_PATH=/ms-playwright
