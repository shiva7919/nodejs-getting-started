pipeline {
  agent any

  environment {
    SONAR_TOKEN = credentials('sonar-token')    // must exist in Jenkins
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
          image 'node:18'
          args  '-v /root/.npm:/root/.npm'
        }
      }
      steps {
        sh '''
          set -eu
          echo "Node: $(node -v) / NPM: $(npm -v)"
          if [ -f package-lock.json ]; then npm ci --no-audit --no-fund; else npm install --no-audit --no-fund; fi
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
        docker { image 'node:18' }    // has GNU tar
      }
      steps {
        sh '''
          set -eu
          echo "Creating artifact (excluding .git and node_modules)..."
          # Create archive in /tmp (outside workspace) to avoid tar reading its own output, then move it back
          TAR_TMP=/tmp/nodeapp-$$.tar.gz
          tar --exclude='.git' --exclude='node_modules' -czf "${TAR_TMP}" .
          mv "${TAR_TMP}" ./nodeapp.tar.gz
          echo "Created nodeapp.tar.gz:"
          ls -lh nodeapp.tar.gz || true
        '''
      }
    }

    stage('Upload to Nexus') {
      agent {
        docker { image 'debian:12-slim' }
      }
      steps {
        // don't fail the whole pipeline if upload fails — mark stage UNSTABLE and continue
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
    success {
      echo "Pipeline succeeded."
    }
    unstable {
      echo "Pipeline is unstable (some non-blocking stage failed). Check logs."
    }
    failure {
      echo "Pipeline failed — check the failing stage output."
    }
  }
}
