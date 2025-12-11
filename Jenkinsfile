pipeline {
    agent {
        label 'build-agent'
    }

    environment {
        VERSION = "${BUILD_NUMBER}" // Tag image with build number only
        DEPLOYMENT_FILE_DIR = './deployment'
        IMAGE_FULL_ADDR = 'registry.ethswitch.et:8443/nbg/nbg-xml-signer-uat'
        MANIFEST_URL = 'github.com/ethswitch/nbg-xml-signer-manifests.git'
        TARGET_BRANCH = 'UAT'
        DEPLOYMENT_FILE = 'deployment.yaml'
        REPOSITORY_URL = "https://${MANIFEST_URL}"
        SLACK_WEBHOOK = credentials('slack-webhook') // Jenkins secret text credential
    }

    stages {
        stage('Prepare Environment') {
            steps {
                script {
                    // Get Git commit metadata
                    env.COMMITTER_NAME = sh(
                        script: """
                            git config --global --add safe.directory ${env.WORKSPACE}
                            git log -1 --pretty=format:'%an'
                        """,
                        returnStdout: true
                    ).trim()

                    env.COMMIT_MESSAGE = sh(
                        script: "git log -1 --pretty=format:'%s'",
                        returnStdout: true
                    ).trim()

                    def BRANCH_NAME = env.JOB_NAME.tokenize('/')[-1]
                    def JOBNAME = env.JOB_NAME.tokenize('/')[1]
                    def J_NAME = "${JOBNAME}-${BRANCH_NAME}:${env.VERSION}"
                    env.J_NAME = J_NAME
                    env.IMAGE_TAG = env.VERSION
                    env.IMAGE_REPO = env.IMAGE_FULL_ADDR

                    echo "Job Name: ${J_NAME}"
                    echo "Branch: ${BRANCH_NAME}"
                    echo "Committer: ${COMMITTER_NAME}"
                }
            }
        }

        stage('Build War File') {
            steps {
                echo 'Building Spring Boot JAR with Gradle...'
                sh 'chmod +x gradlew'
                // sh './gradlew wrapper'
                // sh './gradlew dependencies --no-daemon || true'
                // sh './gradlew spotlessApply clean  build -x test  --no-daemon'
                sh './gradlew build -x test'

            }
        }

        stage('Build and Push Docker Image') {
            steps {
                script {
                    echo "Building Docker image on Jenkins VM agent..."

                    def imageTag = "${IMAGE_FULL_ADDR}:${IMAGE_TAG}"
                    echo "Building image: ${imageTag}"

                    // Build Docker image
                    def appImage = docker.build(imageTag, "--build-arg J_NAME=${J_NAME} .")

                    echo "Pushing Docker image to Harbor registry: ${imageTag}"

                    // Push only build-number-tagged image
                    withCredentials([usernamePassword(credentialsId: 'jenkins-build', usernameVariable: 'HARBOR_USER', passwordVariable: 'HARBOR_PASS')]) {
                        docker.withRegistry("https://${IMAGE_FULL_ADDR.split('/')[0]}", 'jenkins-build') {
                            appImage.push()
                        }
                    }

                    echo "✅ Docker image successfully built and pushed: ${imageTag}"
                }
            }
        }
       stage('Trigger ManifestUpdate') {
           steps {
               echo "triggering updatemanifestjob"
               build job: 'manifest-updater', parameters: [string(name: 'IMAGE_TAG', value: "${VERSION}"), string(name: 'MANIFEST_URL', value: "${MANIFEST_URL}"), string(name: 'DEPLOYMENT_FILE_DIR', value: "${DEPLOYMENT_FILE_DIR}"), string(name: 'TARGET_BRANCH', value: "${TARGET_BRANCH}"), string(name: 'IMAGE_FULL_ADDR', value: "${IMAGE_FULL_ADDR}"), string(name: 'REPOSITORY_URL', value: "${REPOSITORY_URL}")]
           }

       }

    }

    post {
        always {
            script {
                def buildStatus = currentBuild.currentResult ?: 'SUCCESS'
                def statusEmoji = buildStatus == 'SUCCESS' ? '✅' :
                                  buildStatus == 'FAILURE' ? '❌' : '⚠️'
                def themeColor = buildStatus == 'SUCCESS' ? 'good' :
                                 buildStatus == 'FAILURE' ? 'danger' : 'warning'

                def payload = """
                {
                    "text": "${statusEmoji} Build *${buildStatus}* for job *${env.JOB_NAME}* (#${env.BUILD_NUMBER})",
                    "attachments": [
                        {
                            "color": "${themeColor}",
                            "fields": [
                                { "title": "Image", "value": "${env.IMAGE_REPO}", "short": false },
                                { "title": "Tag", "value": "${env.IMAGE_TAG}", "short": true },
                                { "title": "Committer", "value": "${env.COMMITTER_NAME}", "short": true },
                                { "title": "Message", "value": "${env.COMMIT_MESSAGE}", "short": false }
                            ]
                        }
                    ]
                }
                """

                // Notify Slack
                sh(
                    label: 'Notify Slack',
                    script: """curl -s -X POST -H 'Content-type: application/json' -d '${payload}' ${SLACK_WEBHOOK}"""
                )

                echo "Cleaning up workspace..."
                cleanWs()
            }
        }
    }
}
