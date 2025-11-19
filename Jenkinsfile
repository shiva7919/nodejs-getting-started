pipeline {
  agent any

  environment {
    SONAR_TOKEN = credentials('sonar-token')    // ensure this credential exists
  }

  stages {

    stage('Checkout') {
      steps {
        git branch: 'main', url: 'https://github.com/shiva7919/nodejs-getting-started.git'
      }
    }

    stage('Install Dependencies') {
      agent {
        docker {
          image 'node:22'                 // match package engine (20/22/24)
          args  '-u root:root -v /root/.npm:/root/.npm'
        }
      }
      steps {
        sh '''
          set -eu
          echo "Running as: $(id -u):$(id -g) $(id -un 2>/dev/null || true)"
          echo "Node: $(node -v) / NPM: $(npm -v)"
          # remove any existing node_modules that may have wrong perms
          rm -rf node_modules || true
          # Install reproducibly if lockfile exists
          if [ -f package-lock.json ]; then
            npm ci --no-audit --no-fund --unsafe-perm
          else
            npm install --no-audit --no-fund --unsafe-perm
          fi
          # Give workspace back to Jenkins (uid 1000) so subsequent stages can access files
          chown -R 1000:1000 .
        '''
      }
    }

    stage('SonarQube Analysis') {
      agent {
        docker { image 'sonarsource/sonar-scanner-cli:latest' }
      }
      steps {
        sh '''
          set -eu
          echo "Running SonarQube scanner..."
          sonar-scanner \
            -Dsonar.projectKey=nodeapp \
            -Dsonar.sources=. \
            -Dsonar.host.url=http://3.85.22.198:9000 \
            -Dsonar.login=${SONAR_TOKEN}
        '''
      }
    }

    stage('Prepare Artifact') {
      agent {
        docker { image 'node:22' }    // node image has GNU tar
      }
      steps {
        sh '''
          set -eu
          echo "Creating artifact (excluding .git and node_modules)..."
          TAR_TMP=/tmp/nodeapp-$$.tar.gz
          tar --exclude='.git' --exclude='node_modules' -czf "${TAR_TMP}" .
          mv "${TAR_TMP}" ./nodeapp.tar.gz
          ls -lh nodeapp.tar.gz || true
        '''
      }
    }

    stage('Upload to Nexus') {
      agent {
        docker { image 'debian:12-slim' }
      }
      steps {
        catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
          withCredentials([usernamePassword(
            credentialsId: 'nexus',
            usernameVariable: 'NEXUS_USER',
            passwordVariable: 'NEXUS_PASS'
          )]) {
            sh '''
              set -eu
              apt-get update -y
              apt-get install -y --no-install-recommends curl gzip ca-certificates
              echo "Uploading artifact to Nexus..."
              curl -v -u "${NEXUS_USER}:${NEXUS_PASS}" --upload-file nodeapp.tar.gz \
                "http://3.85.22.198:8081/repository/nodejs/nodeapp-$(date +%Y%m%d%H%M%S).tar.gz"
            '''
          }
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
          set -eu
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
            set -eu
            echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
            docker push shivasarla2398/nodeapp:latest
          '''
        }
      }
    }

  } // stages

  post {
    always {
      echo "Pipeline finished!"
      sh 'ls -lh nodeapp.tar.gz || true'
    }
    success { echo "Pipeline succeeded." }
    unstable { echo "Pipeline unstable (non-blocking stage failed)." }
    failure { echo "Pipeline failed — check the failing stage output." }
  }
}
