output "loadbalancer_dns" {
  value = module.loadbalancer.loadbalancer_dns
}

output "route53_dns" {
  value = module.loadbalancer.route53_dns
}
