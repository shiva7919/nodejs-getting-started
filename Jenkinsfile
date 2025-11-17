pipeline {
    agent any

    environment {
        SONAR_TOKEN = credentials('SONAR-TOKEN')
        NEXUS_CRED = credentials('NEXUS-CRED')
        DOCKER_HUB = credentials('DOCKER-HUB')
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main', url: 'https://github.com/KishanGollamudi/nodejs-getting-started.git'
            }
        }

        stage('Install Dependencies') {
            steps {
                sh '''
                    echo "Node version:"
                    node -v

                    echo "NPM version:"
                    npm -v

                    echo Installing Node dependencies...
                    npm install --no-audit --no-fund
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('My-Sonar') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=nodeapp \
                          -Dsonar.sources=. \
                          -Dsonar.host.url=http://54.85.207.105:9000 \
                          -Dsonar.login=$SONAR_TOKEN
                    '''
                }
            }
        }

        stage('Package Artifact') {
            steps {
                sh '''
                    zip -r nodeapp.zip .
                '''
            }
        }

        stage('Upload to Nexus') {
            steps {
                sh '''
                    curl -v -u $NEXUS_CRED_USR:$NEXUS_CRED_PSW \
                        --upload-file nodeapp.zip \
                        http://54.85.207.105:8081/repository/nodejs/nodeapp.zip
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build -t kishan/nodeapp:latest .
                '''
            }
        }

        stage('Push Docker Image') {
            steps {
                sh '''
                    echo $DOCKER_HUB_PSW | docker login -u $DOCKER_HUB_USR --password-stdin
                    docker push kishan/nodeapp:latest
                '''
            }
        }
    }

    post {
        always {
            echo "Pipeline finished!"
        }
    }
}
