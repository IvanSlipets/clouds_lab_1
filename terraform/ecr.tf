resource "aws_ecr_repository" "api" {
  name                 = "${local.name}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = local.tags
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep latest 15 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 15
      }
      action = { type = "expire" }
    }]
  })
}


resource "terraform_data" "bootstrap_image" {
  triggers_replace = [aws_ecr_repository.api.repository_url]

  provisioner "local-exec" {
    interpreter = ["PowerShell", "-NoProfile", "-NonInteractive", "-Command"]
    working_dir = "${path.module}/.."
    command     = <<-EOT
      $ErrorActionPreference = 'Stop'
      $repo = '${aws_ecr_repository.api.repository_url}'
      $registry = $repo.Split('/')[0]
      cmd.exe /d /c "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin $registry"
      if ($LASTEXITCODE -ne 0) {throw 'Docker ECR login failed'}
      docker build --platform linux/amd64 -t "$($repo):${var.image_tag}" .
      if ($LASTEXITCODE -ne 0) { throw 'Docker build failed' }
      docker push "$($repo):${var.image_tag}"
      if ($LASTEXITCODE -ne 0) { throw 'Docker push failed' }
    EOT
  }
}
