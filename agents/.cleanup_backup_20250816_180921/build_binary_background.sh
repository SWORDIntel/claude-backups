#!/bin/bash
# Background Binary System Builder

echo "🔧 Starting background binary system build..."
cd /home/ubuntu/Documents/Claude/agents

# Build components in order of dependency
echo "Building ultra-fast protocol..."
cd binary-communications-system
if ! gcc -O2 -std=c11 -D_GNU_SOURCE -fPIC -msse4.2 -o ultra_hybrid_enhanced ultra_hybrid_enhanced.c -lpthread -lm -lrt 2>>/home/ubuntu/Documents/Claude/agents/binary_build.log; then
    echo "Binary protocol build failed, retrying with basic features..."
    gcc -O1 -std=c11 -D_GNU_SOURCE -fPIC -o ultra_hybrid_enhanced ultra_hybrid_enhanced.c -lpthread -lm -lrt 2>>/home/ubuntu/Documents/Claude/agents/binary_build.log
fi

echo "Building C agent components..."
cd ../src/c
make clean >>/home/ubuntu/Documents/Claude/agents/binary_build.log 2>&1
make all -j4 >>/home/ubuntu/Documents/Claude/agents/binary_build.log 2>&1

echo "Setting up Python integration..."
cd ../python
python3 -c "import ENHANCED_AGENT_INTEGRATION; print('Python integration ready')" >>/home/ubuntu/Documents/Claude/agents/binary_build.log 2>&1

echo "Starting monitoring stack..."
cd ../../monitoring
if command -v docker &> /dev/null; then
    docker-compose -f docker-compose.complete.yml up -d >>/home/ubuntu/Documents/Claude/agents/binary_build.log 2>&1
fi

echo "✅ Binary system build complete!" 
echo "$(date): Binary system ready for transition" >> /home/ubuntu/Documents/Claude/agents/binary_build.log
