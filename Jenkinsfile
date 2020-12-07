@Library('cicd-utils')_
pipeline {
    agent {
        label "master"
    }

    environment {
        SLACK_CHANNEL = '#integration-log'
        BASE_REPOSITORY_URI = "184806450101.dkr.ecr.eu-west-1.amazonaws.com/base"
        PROJECT_REPOSITORY_URI = "184806450101.dkr.ecr.eu-west-1.amazonaws.com/project"
        SUBSTR_COMMIT ="${GIT_COMMIT}".substring(0,7)
        PROJECT_NAME = "shipit"
        NAMESPACE = "shipit"
        HELM_CHART_PATH = "helm_chart"
        GIT_PRIVATE_KEY = "github_private_key"
        IMAGE_TAG = "shipit-${SUBSTR_COMMIT}"
    }

    options {
        timeout(time: 45, unit: 'MINUTES')
        timestamps()
        disableConcurrentBuilds()
        ansiColor('xterm')
        buildDiscarder(logRotator(daysToKeepStr: '30'))
    }

    parameters {
        booleanParam(name: 'BUILD_IMAGES_ONLY', defaultValue: false, description: 'If checked it will build the docker images' +
                'push it to the docker registry. It will not deploy the project.')
        booleanParam(name: 'FORCE_REBUILD_IMAGES', defaultValue: false, description: 'If checked it will force rebuild the images' +
            ' (Dockerfile-to-deploy) from scratch before pushing it to the docker registry.')
        booleanParam(name: 'FORCE_RECREATE_POD', defaultValue: false, description: 'If checked it will recreate the pod even if there are no changes')
    }

    stages {
        stage('Building/Pushing docker image') {
            steps {
                script{
                    buildAndPush("integration")
                }
            }
        }
        stage('Testing') {
            agent {
                docker {
                    image "${PROJECT_REPOSITORY_URI}:${IMAGE_TAG}"
                    args "-e RAILS_ENV=test --entrypoint=''"
                    label "master"
                }
            }            
            steps {
                script{
                    dir("test/dummy"){
                        sh "RAILS_ENV=test bundle exec rake db:create db:schema:load test"
                    }
                }
            }
        }

        stage('Deploying') {
            agent {
                docker {
                    image "${BASE_REPOSITORY_URI}:aws-kubectl-helm-agent"
                    args "-u root"
                    label "master"
                }
            }
            when {
                expression {
                    return params.BUILD_IMAGES_ONLY == false
                }
            }
            steps {
                script {
                    deploy("integration", "integration","eu-central-1")
                    // deploy("production", "production","us-east-1")

                    // // run db migrate inside the pod
                    // sleep 15 // wait for terminating pod
                    // shipit_pod = sh(returnStdout: true, script: "kubectl get pods -n shipit | grep shipit-app | cut -d' ' -f1 | tr -d '\n'").trim()
                    // sh "kubectl exec ${shipit_pod} -n ${NAMESPACE} -- bundle exec rake db:create db:migrate"
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
    }
}


def buildAndPush(String environment) {
sh """
        docker build -t ${PROJECT_REPOSITORY_URI}:${IMAGE_TAG} \
        --build-arg RAILS_ENV=production .
        docker push ${PROJECT_REPOSITORY_URI}:${IMAGE_TAG}
    """
}

def deploy(String environment, String cluster_name, String aws_region, String values_files = null) {
    connectToKubernetesCluster(aws_region, cluster_name, "aws_credentials")
    deployToKubernetesCluster(environment, "${NAMESPACE}", "helm_chart","${IMAGE_TAG}", "shipit","values.yaml", "--set deployment.app.image_tag=${IMAGE_TAG}")
}
