pipeline {
  agent any

  environment {
    // Make sure these credentials exist in Jenkins with these IDs
    SONAR_TOKEN = credentials('sonar-token')
    // NEXUS and DOCKERHUB credentials are used with withCredentials below
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: 'main',
            url: 'https://github.com/shiva7919/nodejs-getting-started.git'
      }
    }

    stage('Install Dependencies') {
      // Use official node image so node/npm are available
      agent {
        docker {
          image 'node:18'
          args  '-u root:root -v /root/.npm:/root/.npm' // run as root to avoid permission issues
        }
      }
      steps {
        sh '''
          set -e
          echo "Node version: $(node -v)"
          echo "NPM version: $(npm -v)"
          echo "Installing Node dependencies..."
          npm ci --no-audit --no-fund
        '''
      }
    }

    stage('SonarQube Analysis') {
      // Use sonar-scanner image
      agent {
        docker { image 'sonarsource/sonar-scanner-cli:latest' }
      }
      steps {
        // If you have SonarQube configured in Jenkins you can also use withSonarQubeEnv('My-Sonar')
        sh '''
          set -e
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
            set -e
            echo "Packaging artifact..."
            tar --ignore-failed-read --warning=no-file-changed -czf nodeapp.tar.gz *
            echo "Uploading to Nexus..."
            curl -v -u ${NEXUS_USER}:${NEXUS_PASS} --upload-file nodeapp.tar.gz \
              http://3.85.22.198:8081/repository/nodejs/nodeapp-$(date +%Y%m%d%H%M%S).tar.gz
          '''
        }
      }
    }

    stage('Build Docker Image') {
      // Use Docker CLI image and mount the host docker socket so it uses host Docker (DooD)
      agent {
        docker {
          image 'docker:24.0.5-cli'
          args  '-v /var/run/docker.sock:/var/run/docker.sock'
        }
      }
      steps {
        sh '''
          set -e
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
            set -e
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
