output "nginx-static-app" {
  value = kubernetes_service.nginx-static-app.status.0.load_balancer.0.ingress.0.ip
}