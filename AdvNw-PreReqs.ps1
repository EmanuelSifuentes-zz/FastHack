$loc = Read-Host -Prompt "Enter your location: "
$rg = New-AzResourceGroup -Name 'AdvNw-WTH-RG' -Location $loc

$gwsncfg = New-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -AddressPrefix 10.0.0.0/24
$workloadsncfg = New-AzVirtualNetworkSubnetConfig -Name 'Workload' -AddressPrefix 10.0.10.0/24
$azfwsncfg = New-AzVirtualNetworkSubnetConfig -Name 'AzureFirewallSubnet' -AddressPrefix 10.0.1.0/24
$appgwsncfg = New-AzVirtualNetworkSubnetConfig -Name 'AppGwSubnet' -AddressPrefix 10.0.2.0/24

$hub = New-AzVirtualNetwork -Name 'Hub-VNET' -ResourceGroupName $rg.ResourceGroupName -Location $loc -AddressPrefix 10.0.0.0/16 -Subnet $gwsncfg, $workloadsncfg, $azfwsncfg, $appgwsncfg

$gwsn = Get-AzVirtualNetworkSubnetConfig -Name $gwsncfg.Name -VirtualNetwork $hub

$gwpip = New-AzPublicIpAddress -Name 'Hub-VPN-GW-PIP' -Location $loc -ResourceGroupName $rg.ResourceGroupName -Sku Standard -AllocationMethod Static
$azfwpip = New-AzPublicIpAddress -Name 'Hub-AzFw-PIP' -Location $loc -ResourceGroupName $rg.ResourceGroupName -Sku Standard -AllocationMethod Static

$gwipconfig = New-AzVirtualNetworkGatewayIpConfig -Name 'Hub-VPN-GW-IPConfig' -SubnetId $gwsn.Id -PublicIpAddressId $gwpip.Id

New-AzVirtualNetworkGateway -Name 'Hub-VPN-GW' -ResourceGroupName $rg.ResourceGroupName -Location $loc -IpConfigurations $gwipconfig -GatewayType 'Vpn' -VpnType "RouteBased" -GatewaySku VpnGw2 -VpnGatewayGeneration Generation2 -AsJob

/*New-AzFirewall -Name 'Hub-AzFw' -ResourceGroupName $rg.ResourceGroupName -Location $loc -VirtualNetwork $hub -PublicIpAddress $azfwpip -AsJob*/