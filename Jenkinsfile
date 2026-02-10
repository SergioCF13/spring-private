pipeline {
  agent any
  environment {
    GIT_BRANCH = "main"
    GIT_URL = "https://github.com/JuanAndresRomanYanez/springboot-app-private.git"
    GIT_CREDENTIALS_ID = "github-token"

    CANARY_PORT = "8082"  // <<< Puerto de pruebas (20% tráfico)
    PROD_PORT = "8081"    // <<< Puerto estable (80% tráfico)

    SSH_KEY_PATH = "/var/jenkins_home/.ssh/id_ed25519"
    REMOTE_USER = "osboxes"
    REMOTE_HOST = "192.168.100.161"
    REMOTE_ARTIFACT_DIR = "/home/osboxes/artifacts/spring-boot-private"
    DEPLOY_SCRIPT = "/opt/spring-boot-app/deploy.sh"
    JAR_GLOB = "target/*.jar"
    JAR_NAME = "demo-0.0.1-SNAPSHOT.jar"
  }
  stages {
    stage('Checkout') {
      steps {
        git branch: "${GIT_BRANCH}", url: "${GIT_URL}", credentialsId: "${GIT_CREDENTIALS_ID}"
        sh 'echo "Checkout del repositorio completado..."'
      }
    }
    stage('Build') {
      steps {
          echo "Compilando y empaquetando..."
          sh 'mvn clean package -DskipTests'
         }
    }

    stage('Test') {
        steps {
            echo "Ejecutando pruebas unitarias..."
            sh 'mvn test'
        }
    }

    stage('Deploy Canary (8082)') {
      steps {
        sh 'echo "Deploying to Canary instance..."'
        sh "scp -i ${SSH_KEY_PATH} ${JAR_GLOB} ${REMOTE_USER}@${REMOTE_HOST}:${REMOTE_ARTIFACT_DIR}/"
        sh "ssh ${REMOTE_USER}@${REMOTE_HOST} -i ${SSH_KEY_PATH} \"sudo ${DEPLOY_SCRIPT} ${REMOTE_ARTIFACT_DIR}/${JAR_NAME} ${CANARY_PORT}\""
        sh 'echo "Canary Deploy completado"'
      }
    }

    stage('Validation Check') {
      steps {
        script {
            // Esto pausará el pipeline hasta darle "Continuar" en la web de Jenkins
            input message: '¿El Canary (8082) funciona bien? ¿Promocionar a Producción?', ok: 'Sí, Promocionar'
        }
      }
    }

    stage('Promote to Stable (8081)') {
      steps {
        sh 'echo "Promoting to Stable instance..."'
        sh "ssh ${REMOTE_USER}@${REMOTE_HOST} -i ${SSH_KEY_PATH} \"sudo ${DEPLOY_SCRIPT} ${REMOTE_ARTIFACT_DIR}/${JAR_NAME} ${PROD_PORT}\""
        sh 'echo "Promoción completada"'
      }
    }

  }
  post {
    always {
      archiveArtifacts artifacts: 'target/*.jar', fingerprint: true
    }
    success {
      echo "Pipeline exitoso. La aplicación está actualizada en ambos puertos."
    }
    
    // ROLLBACK AUTOMÁTICO EN CASO DE FALLO ---
    failure {
      echo "❌ El pipeline falló. Iniciando Rollback automático en Canary..."
      script {
          // Si falla el deploy, le decimos al script que haga ROLLBACK en el puerto Canary
          // Nota: Usamos la palabra clave 'rollback' que se programo en el deploy.sh
          sh "ssh ${REMOTE_USER}@${REMOTE_HOST} -i ${SSH_KEY_PATH} \"sudo ${DEPLOY_SCRIPT} rollback ${CANARY_PORT}\""
      }
      echo "✅ Rollback ejecutado. Versión anterior restaurada."
    }
  }
}