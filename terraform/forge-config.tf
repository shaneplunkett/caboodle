locals {
  forge_org = "shane"
}

import {
  to = forgejo_team.bots
  id = "${local.forge_org}/bots"
}

resource "forgejo_team" "bots" {
  organization              = local.forge_org
  name                      = "bots"
  permission                = "read"
  includes_all_repositories = true
  units_map = {
    "repo.actions"    = "write"
    "repo.code"       = "write"
    "repo.ext_issues" = "read"
    "repo.ext_wiki"   = "read"
    "repo.issues"     = "write"
    "repo.packages"   = "write"
    "repo.projects"   = "write"
    "repo.pulls"      = "write"
    "repo.releases"   = "read"
    "repo.wiki"       = "write"
  }
}

resource "forgejo_team_member" "bots" {
  for_each = toset(["forge-bot", "vex"])
  team_id  = forgejo_team.bots.id
  user     = each.key
}

resource "forgejo_repository" "workflows" {
  owner              = local.forge_org
  name               = "workflows"
  description        = "Forgejo Actions workflows the other repos call, pinned by tag."
  archive_on_destroy = true
}
