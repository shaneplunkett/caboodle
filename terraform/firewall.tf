data "unifi_firewall_zone" "internal" {
  name = "Internal"
}

data "unifi_network" "lan" {
  name = "LAN"
}

data "unifi_network" "iot" {
  name = "IOT"
}

import {
  to = unifi_firewall_zone.iot
  id = "68313482b19a8b4bb609f494"
}

resource "unifi_firewall_zone" "iot" {
  name        = "IOT"
  network_ids = [data.unifi_network.iot.id]
}

import {
  to = unifi_firewall_policy.iot_comms
  id = "68317941b19a8b4bb60a91ee"
}

resource "unifi_firewall_policy" "iot_comms" {
  name                 = "IOT Comms"
  action               = "ALLOW"
  create_allow_respond = true
  protocol             = "all"
  ip_version           = "BOTH"

  source = {
    zone_id         = unifi_firewall_zone.iot.id
    matching_target = "ANY"
  }

  destination = {
    zone_id         = unifi_firewall_zone.iot.id
    matching_target = "ANY"
  }
}

import {
  to = unifi_firewall_policy.home_assistant
  id = "6ac9a3406d7155a86042945a"
}

resource "unifi_firewall_policy" "home_assistant" {
  name                 = "Home Assistant to IoT"
  description          = "Let Home Assistant on the home host discover and control the smart home devices on the IoT VLAN."
  action               = "ALLOW"
  create_allow_respond = true
  protocol             = "all"
  ip_version           = "IPV4"

  source = {
    zone_id         = data.unifi_firewall_zone.internal.id
    matching_target = "IP"
    ips             = [local.lan_addresses.home]
  }

  destination = {
    zone_id         = unifi_firewall_zone.iot.id
    matching_target = "ANY"
  }
}

import {
  to = unifi_firewall_policy.bose
  id = "6a7fe91befb91ed8071041e0"
}

resource "unifi_firewall_policy" "bose" {
  name                 = "Bose Soundbar Control"
  description          = "Allow trusted LAN devices to discover and control the Bose Smart Soundbar 900 on the isolated IoT VLAN."
  action               = "ALLOW"
  create_allow_respond = true
  protocol             = "tcp_udp"
  ip_version           = "IPV4"

  source = {
    zone_id         = data.unifi_firewall_zone.internal.id
    matching_target = "NETWORK"
    network_ids     = [data.unifi_network.lan.id]
  }

  destination = {
    zone_id         = unifi_firewall_zone.iot.id
    matching_target = "IP"
    ips = [
      unifi_client.device["Bose Soundbar (Ethernet)"].fixed_ip,
      unifi_client.device["Bose Soundbar"].fixed_ip,
    ]
  }
}

import {
  to = unifi_firewall_policy.gaggiuino
  id = "68aab564307e7930ffc753c2"
}

resource "unifi_firewall_policy" "gaggiuino" {
  name                 = "Gaggiuino"
  action               = "ALLOW"
  create_allow_respond = true
  protocol             = "tcp_udp"
  ip_version           = "BOTH"

  source = {
    zone_id         = data.unifi_firewall_zone.internal.id
    matching_target = "ANY"
  }

  destination = {
    zone_id            = unifi_firewall_zone.iot.id
    matching_target    = "IP"
    ips                = [unifi_client.device["Gaggiuino"].fixed_ip]
    port_matching_type = "SPECIFIC"
    port               = "80"
  }
}

import {
  to = unifi_firewall_policy.slzb
  id = "68aabdb8307e7930ffc76193"
}

resource "unifi_firewall_policy" "slzb" {
  name                 = "SLZ"
  action               = "ALLOW"
  create_allow_respond = true
  protocol             = "tcp_udp"
  ip_version           = "BOTH"

  source = {
    zone_id         = data.unifi_firewall_zone.internal.id
    matching_target = "ANY"
  }

  destination = {
    zone_id            = unifi_firewall_zone.iot.id
    matching_target    = "IP"
    ips                = [unifi_client.device["SLZB"].fixed_ip]
    port_matching_type = "SPECIFIC"
    port               = "80"
  }
}

data "unifi_firewall_zone" "external" {
  name = "External"
}

locals {
  lg_tv_macs = [
    unifi_client.device["LG TV (Ethernet)"].mac,
    unifi_client.device["LG TV"].mac,
  ]
}

resource "unifi_firewall_policy" "lg_tv_internet" {
  for_each = {
    IOT      = unifi_firewall_zone.iot.id
    Internal = data.unifi_firewall_zone.internal.id
  }

  name        = "LG TV Internet (${each.key})"
  description = "Keep the LG TV off the internet, by both its MACs, whichever network it lands on."
  action      = "BLOCK"
  protocol    = "all"
  ip_version  = "BOTH"

  source = {
    zone_id         = each.value
    matching_target = "CLIENT"
    client_macs     = local.lg_tv_macs
  }

  destination = {
    zone_id         = data.unifi_firewall_zone.external.id
    matching_target = "ANY"
  }
}
