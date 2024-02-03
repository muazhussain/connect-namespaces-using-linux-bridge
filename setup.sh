#!/bin/bash

# Virtual Machine
VM_NAME='ubuntuvm'
VM_CPU_COUNT=2
VM_MEMORY='2G'
VM_DISK='10G'

# Linux Bridge
BRIDGE_NAME='starship'
BRIDGE_IP='10.0.0.1/24'

# Network Namespaces
NAMESPACE_1='earth'
NAMESPACE_2='mars'

# Virtual Ethernet Pairs
VETH_NAMESPACE1_GREEN='earth-green'
VETH_NAMESPACE1_RED='earth-red'
VETH_NAMESPACE2_GREEN='mars-green'
VETH_NAMESPACE2_RED='mars-red'

# IP Addresses for Namespace Interfaces
IP_NAMESPACE1_GREEN='10.0.0.11/24'
IP_NAMESPACE2_GREEN='10.0.0.21/24'

# Default Gateway
GATEWAY_IP='10.0.0.1'

# Launch Virtual Machine
multipass launch -c "$VM_CPU_COUNT" -m "$VM_MEMORY" -d "$VM_DISK" -n "$VM_NAME"

# Access Virtual Machine
multipass shell "$VM_NAME"

# Create Linux Bridge
sudo ip link add dev "$BRIDGE_NAME" type bridge
sudo ip link set dev "$BRIDGE_NAME" up
sudo ip address add "$BRIDGE_IP" dev "$BRIDGE_NAME"

# Create Network Namespaces
sudo ip netns add "$NAMESPACE_1"
sudo ip netns add "$NAMESPACE_2"

# Create Virtual Ethernet Pairs
sudo ip link add "$VETH_NAMESPACE1_GREEN" type veth peer name "$VETH_NAMESPACE1_RED"
sudo ip link add "$VETH_NAMESPACE2_GREEN" type veth peer name "$VETH_NAMESPACE2_RED"

# Move Virtual Ethernet Pairs to Respective Namespaces
sudo ip link set dev "$VETH_NAMESPACE1_GREEN" netns "$NAMESPACE_1"
sudo ip link set dev "$VETH_NAMESPACE2_GREEN" netns "$NAMESPACE_2"

# Add Virtual Ethernet Pairs to the Bridge
sudo ip link set dev "$VETH_NAMESPACE1_RED" master "$BRIDGE_NAME"
sudo ip link set dev "$VETH_NAMESPACE2_RED" master "$BRIDGE_NAME"

# Set Interfaces and Namespace Interfaces Up
sudo ip link set dev "$VETH_NAMESPACE1_RED" up
sudo ip link set dev "$VETH_NAMESPACE2_RED" up
sudo ip netns exec "$NAMESPACE_1" ip link set dev "$VETH_NAMESPACE1_GREEN" up
sudo ip netns exec "$NAMESPACE_2" ip link set dev "$VETH_NAMESPACE2_GREEN" up

# Assign IP Addresses to Namespace Interfaces
sudo ip netns exec "$NAMESPACE_1" ip address add "$IP_NAMESPACE1_GREEN" dev "$VETH_NAMESPACE1_GREEN"
sudo ip netns exec "$NAMESPACE_2" ip address add "$IP_NAMESPACE2_GREEN" dev "$VETH_NAMESPACE2_GREEN"

# Set Default Routes in Namespaces
sudo ip netns exec "$NAMESPACE_1" ip route add default via "$GATEWAY_IP"
sudo ip netns exec "$NAMESPACE_2" ip route add default via "$GATEWAY_IP"

# Set Firewall Rules
sudo iptables --append FORWARD --in-interface "$BRIDGE_NAME" --jump ACCEPT
sudo iptables --append FORWARD --out-interface "$BRIDGE_NAME" --jump ACCEPT

# Test Connectivity
sudo ip netns exec "$NAMESPACE_2" ping -c 2 "$IP_NAMESPACE1_GREEN"
sudo ip netns exec "$NAMESPACE_1" ping -c 2 "$IP_NAMESPACE2_GREEN"
