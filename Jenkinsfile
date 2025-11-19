pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('sonar-token')
        NEXUS_CRED  = credentials('NEXUS-CRED')
        DOCKER_HUB  = credentials('dockerhub')
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/shiva7919/nodejs-getting-started.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    echo "Node version:"
                    node -v

                    echo "NPM version:"
                    npm -v

                    echo "Installing Node dependencies..."
                    npm install --no-audit --no-fund
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('My-Sonar') {
                    sh '''
                        /opt/sonar-scanner/bin/sonar-scanner \
                          -Dsonar.projectKey=nodeapp \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=http://3.85.22.198:9000 \
                          -Dsonar.login=$SONAR_TOKEN
                    '''
                }
            }
        }

        stage('Upload to Nexus') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'NEXUS-CRED',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {

                    sh '''
                        echo "Creating TAR..."
                        tar --ignore-failed-read --warning=no-file-changed \
                            -czf nodeapp.tar.gz *

                        echo "Uploading TAR to Nexus..."
                        curl -v -u $NEXUS_USER:$NEXUS_PASS \
                            --upload-file nodeapp.tar.gz \
                            http://3.85.22.198:8081/repository/nodejs/nodeapp.tar.gz
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "Building Docker image..."
                    docker build -t shivasarla2398/nodeapp:latest .
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {

                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin
                        docker push shivasarla2398/nodeapp:latest
                    '''
                }
            }
        }
    }   // ✅ THIS was missing (closing stages)

    post {
        always {
            echo "Pipeline finished!"
        }
    }
}
