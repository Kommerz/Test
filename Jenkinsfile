#!/bin/groovy

node ('testslave') {

   stage 'Clone Repository'
   checkout scm

   stage 'Initialization'
   stash ('original-repo') // Save original state of all files for later use on other nodes
   
   env.DOCKER_IMAGE_NAME = 'raphaelherding/pet-clinic-v3'
   env.KUBERNETES_URL = 'https://52.7.176.186'
   env.NEXUS_URL = 'nexus.itgo-devops.org:18444'
   env.NEXUS_DOCKER_IMAGE_NAME = "${env.NEXUS_URL}/admin/petclinic"
   
   echo "KUBERNETES_URL=${env.KUBERNETES_URL}"
   echo "NEXUS_URL=${env.NEXUS_URL}"
   echo "NEXUS_DOCKER_IMAGE_NAME=${env.NEXUS_DOCKER_IMAGE_NAME}"
   echo "BUILD_NUMBER=${env.BUILD_NUMBER}"
   echo "BRANCH_NAME=${env.BRANCH_NAME}"
   echo "NODE_AGENT=${env.NODE_AGENT}"
   echo "NODE_LABELS=${env.NODE_LABELS}"
   echo "DOCKER_CERT_PATH=${env.DOCKER_CERT_PATH}"
   echo "DOCKER_HOST=${env.DOCKER_HOST}"
   echo "DOCKER_TLS_VERIFY=${env.DOCKER_TLS_VERIFY}"
   echo "DOCKER_IMAGE_NAME=${env.DOCKER_IMAGE_NAME}"
   // Uncomment the next line to see informatino regarding the docker daemon for creating new docker images
   //sh 'docker info'

   stage 'Build'
   // Patch Buildnumber into ApplicationTitle:
   sh "sed -e ''s/{BUILDNUMBER}/${env.BUILD_NUMBER}/g'' src/main/resources/messages/messages.properties > src/main/resources/messages/messages_patched.properties"
   sh "cat src/main/resources/messages/messages_patched.properties > src/main/resources/messages/messages.properties"

   sh 'chmod +x gradlew' // set execute permission for gradlew
   sh './gradlew build -x test'

   stage 'Test'
   sh './gradlew test'

   stage 'Create Docker Image'
   docker.withRegistry("https://${env.NEXUS_URL}", 'Nexus-Admin') {
   		sh './gradlew buildDocker -x test -x build'
   }
   

   stage 'Tag and Push Docker Image to Nexus'
   // Rename Tag for Nexus
   sh "docker tag ${env.DOCKER_IMAGE_NAME}:latest ${env.NEXUS_DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}"
   sh "docker rmi ${env.DOCKER_IMAGE_NAME}:latest"
   sh "docker tag ${env.NEXUS_DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER} ${env.NEXUS_DOCKER_IMAGE_NAME}:latest"
   // Push
   docker.withRegistry("https://${env.NEXUS_URL}", 'Nexus-Admin') {
      sh "docker push ${env.NEXUS_DOCKER_IMAGE_NAME}:latest"
      sh "docker push ${env.NEXUS_DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}"
   }
   // Remove Images from Drydock after push
   sh "docker rmi ${env.NEXUS_DOCKER_IMAGE_NAME}:latest"
   sh "docker rmi ${env.NEXUS_DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}"
   

   stage 'Deploy on Test'
   kubernetesRollingUpdateOrCreate('petclinic-dev', 'petclinic-replication-controller-dev', 'kubernetes-deployment-dev.yaml', "${env.NEXUS_DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}")
}

node {
   stage 'Confirm Deployment on Production?'
   timeout(time:5, unit:'DAYS') {
      input message:'Deploy to production stage?', ok: 'Yes'//, submitter: 'it-ops'
   }
   echo 'OK'
}

node ('testslave') {
   stage 'Deploy on Production'
   unstash ('original-repo') // Restore original state

   kubernetesRollingUpdateOrCreate('petclinic-prod2', 'petclinic-replication-controller-prod2', 'kubernetes-deployment-prod.yaml', "${env.NEXUS_DOCKER_IMAGE_NAME}:${env.BUILD_NUMBER}")
}

def kubernetesRollingUpdateOrCreate(serviceName, replicationControllerName, deploymentFileName, dockerImageName){
   if(!fileExists('./kubectl')){ 
      // Download Kubernetes and set execute permission
      sh 'wget https://storage.googleapis.com/kubernetes-release/release/v1.2.4/bin/linux/amd64/kubectl'
      sh 'chmod +x kubectl'
   }
   
   withCredentials([[$class: 'UsernamePasswordMultiBinding', credentialsId: 'Kubernetes', passwordVariable: 'kubernetesPwd', usernameVariable: 'kubernetesUser']]) {
      // Uncomment the next line to see current pods
      //sh "./kubectl --server=${env.KUBERNETES_URL} --username=${env.kubernetesUser} --password=${env.kubernetesPwd} --insecure-skip-tls-verify=true get pods"

      def rc = sh (
         script: "./kubectl --server=${env.KUBERNETES_URL} --username=${env.kubernetesUser} --password=${env.kubernetesPwd} --insecure-skip-tls-verify=true get service ${serviceName}",
         returnStatus: true
      )
      if(rc == 0){ // service exists => rollind update
         echo "Doing rolling update for service ${serviceName}..."
         // sh "./kubectl --server=${env.KUBERNETES_URL} --username=${env.kubernetesUser} --password=${env.kubernetesPwd} --insecure-skip-tls-verify=true rolling-update ${replicationControllerName} --image=${dockerImageName}"
 
         sh "./kubectl --server=${env.KUBERNETES_URL} --username=${env.kubernetesUser} --password=${env.kubernetesPwd} --insecure-skip-tls-verify=true apply -f ${deploymentFileName}"
      }
      else{
         echo "RC=${rc}. Service ${serviceName} does not exists. Creating from file ${deploymentFileName} ..."
         sh "./kubectl --server=${env.KUBERNETES_URL} --username=${env.kubernetesUser} --password=${env.kubernetesPwd} --insecure-skip-tls-verify=true create -f ${deploymentFileName}"
      }
      echo "Status of service ${serviceName}:"
      sh "./kubectl --server=${env.KUBERNETES_URL} --username=${env.kubernetesUser} --password=${env.kubernetesPwd} --insecure-skip-tls-verify=true get service ${serviceName}"

      echo "URL for LoadBalancer:"
      sh "./kubectl --server=${env.KUBERNETES_URL} --username=${env.kubernetesUser} --password=${env.kubernetesPwd} --insecure-skip-tls-verify=true describe service ${serviceName} | grep 'LoadBalancer Ingress'"
   
      // Uncomment the next line to see current pods
      //sh "./kubectl --server=${env.KUBERNETES_URL} --username=${env.kubernetesUser} --password=${env.kubernetesPwd} --insecure-skip-tls-verify=true get pods"
   }
}
