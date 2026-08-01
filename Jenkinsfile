// ============================================================================
// 文件: Jenkinsfile
// 作用: 定义 Jenkins Pipeline（CI/CD 流水线）
//
// 用法:
//   1. 把这个文件放到 ~/myapp/ 目录下（和 index.html、Dockerfile 同级）
//   2. 在 Jenkins Web UI 中创建 Pipeline 任务，选择 "Pipeline script from SCM"
//   3. SCM 选择 Git，Repository URL 填 file:///home/你的用户名/myapp
//   4. 保存后点击 "立即构建"
//
// 注意: 本文件中的 /home/ace/ 路径需要根据你的实际家目录修改
//       或者使用环境变量 MONITORING_LAB_PATH 指定项目路径
// ============================================================================

pipeline {
    agent any

    environment {
        // 项目路径: 请根据你的实际家目录修改
        // 例如: /home/yourname/monitoring-lab 或 /Users/yourname/monitoring-lab
        MONITORING_LAB_PATH = '/home/ace/monitoring-lab'

        // 镜像仓库地址
        REGISTRY = sh(script: '''
            if [ -f ${MONITORING_LAB_PATH}/.env ]; then
                source ${MONITORING_LAB_PATH}/.env
                echo "${DOCKER_GATEWAY}:5000"
            else
                docker network inspect bridge --format='{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || echo "172.17.0.1:5000"
            fi
        ''', returnStdout: true).trim()

        IMAGE = 'nginx-demo'
        TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                // 注意: 请把 /home/ace 替换为你的实际家目录
                git url: 'file:///home/ace/myapp', branch: 'main'
            }
        }

        stage('Build & Test') {
            parallel {
                stage('Build Image') {
                    steps {
                        sh "docker build -t ${IMAGE}:${TAG} ."
                        sh "docker tag ${IMAGE}:${TAG} ${REGISTRY}/${IMAGE}:${TAG}"
                    }
                }
                stage('Unit Test') {
                    steps {
                        sh 'test -s index.html && echo "HTML file OK"'
                    }
                }
            }
        }

        stage('Security Scan') {
            steps {
                sh '''
                    if command -v trivy >/dev/null 2>&1; then
                        trivy image --severity HIGH,CRITICAL --exit-code 0 ${IMAGE}:${TAG}
                    else
                        echo "[WARN] Trivy 未安装，跳过安全扫描"
                    fi
                '''
            }
        }

        stage('Push') {
            steps {
                sh "docker push ${REGISTRY}/${IMAGE}:${TAG}"
            }
        }

        stage('Sign Image') {
            steps {
                sh '''
                    if command -v cosign >/dev/null 2>&1; then
                        cosign sign --key cosign.key ${REGISTRY}/${IMAGE}:${TAG} || echo "[WARN] 签名失败，继续部署"
                    else
                        echo "[WARN] Cosign 未安装，跳过镜像签名"
                    fi
                '''
            }
        }

        stage('Deploy') {
            steps {
                sh "kubectl set image deployment/nginx-demo nginx=${REGISTRY}/${IMAGE}:${TAG}"
                sh "kubectl rollout status deployment/nginx-demo --timeout=120s"
            }
        }
    }

    post {
        always {
            sh "docker system prune -f || true"
            writeFile file: "build-info.txt", text: "Build: ${env.BUILD_NUMBER}\nImage: ${REGISTRY}/${IMAGE}:${TAG}\nTime: ${new Date()}"
            archiveArtifacts artifacts: "build-info.txt", allowEmptyArchive: true
        }
        failure {
            echo "[FAIL] 构建失败，请检查日志"
        }
        success {
            echo "[OK] 构建并部署成功!"
        }
    }
}
