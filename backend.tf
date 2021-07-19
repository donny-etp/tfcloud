terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "emrge"

    workspaces {
      name = "donny-workspace"
    }
  }
}