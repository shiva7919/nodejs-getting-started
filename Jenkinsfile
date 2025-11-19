pipeline {
  agent any

  environment {
    // Ensure these credentials exist in Jenkins (IDs must match)
    SONAR_TOKEN = credentials('sonar-token')
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main',
            url: 'https://github.com/shiva7919/nodejs-getting-started.git'
      }
    }

    stage('Install Dependencies') {
      agent {
        docker {
          image 'node:18'
          args  '-u root:root -v /root/.npm:/root/.npm'
        }
      }
      steps {
        sh '''
          set -euo pipefail
          echo "Node version: $(node -v)"
          echo "NPM version: $(npm -v)"
          echo "Installing Node dependencies..."
          # Prefer npm ci when lockfile exists; fallback to npm install
          if [ -f package-lock.json ]; then
            npm ci --no-audit --no-fund
          else
            npm install --no-audit --no-fund
          fi
        '''
      }
    }

    stage('SonarQube Analysis') {
      agent {
        docker { image 'sonarsource/sonar-scanner-cli:latest' }
      }
      steps {
        sh '''
          set -euo pipefail
          echo "Running SonarQube scanner..."
          sonar-scanner \
            -Dsonar.projectKey=nodeapp \
            -Dsonar.sources=. \
            -Dsonar.host.url=http://3.85.22.198:9000 \
            -Dsonar.login=${SONAR_TOKEN}
        '''
      }
    }

    stage('Upload to Nexus') {
      agent { docker { image 'curlimages/curl:8.2.1' } }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'nexus',
          usernameVariable: 'NEXUS_USER',
          passwordVariable: 'NEXUS_PASS'
        )]) {
          sh '''
            set -euo pipefail
            echo "Packaging artifact (excluding .git and node_modules)..."
            # BusyBox tar (used in some images) supports --exclude, avoid GNU-only flags
            tar -czf nodeapp.tar.gz . --exclude=.git --exclude=node_modules || true

            echo "Artifact size:"
            ls -lh nodeapp.tar.gz || true

            echo "Uploading to Nexus..."
            curl -v -u ${NEXUS_USER}:${NEXUS_PASS} --upload-file nodeapp.tar.gz \
              http://3.85.22.198:8081/repository/nodejs/nodeapp-$(date +%Y%m%d%H%M%S).tar.gz
          '''
        }
      }
    }

    stage('Build Docker Image') {
      agent {
        docker {
          image 'docker:24.0.5-cli'
          args  '-v /var/run/docker.sock:/var/run/docker.sock'
        }
      }
      steps {
        sh '''
          set -euo pipefail
          echo "Building Docker image..."
          docker build -t shivasarla2398/nodeapp:latest .
        '''
      }
    }

    stage('Push Docker Image') {
      agent {
        docker {
          image 'docker:24.0.5-cli'
          args  '-v /var/run/docker.sock:/var/run/docker.sock'
        }
      }
      steps {
        withCredentials([usernamePassword(
          credentialsId: 'dockerhub',
          usernameVariable: 'DOCKER_USER',
          passwordVariable: 'DOCKER_PASS'
        )]) {
          sh '''
            set -euo pipefail
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push shivasarla2398/nodeapp:latest
          '''
        }
      }
    }
  }

  post {
    always {
      echo "Pipeline finished!"
    }
    success {
      echo "Pipeline succeeded."
    }
    failure {
      echo "Pipeline failed — check the logs above for the failing stage."
    }
  }
}
