output "config" {
  description = "Commands to run in cloud9 environment to configure kafka"
  value = data.template_file.config.rendered
}