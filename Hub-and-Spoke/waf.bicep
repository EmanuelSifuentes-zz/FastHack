@description('The location into which the Application Gateway resources should be deployed.')
param location string = resourceGroup().location

@description('The unique ID associated with the Front Door profile that will send traffic to this application. The Application Gateway WAF will be configured to disallow traffic that hasn\'t had this ID attached to it.')
param frontDoorUniqueId string

@description('The mode (prevention or detection) chosen for the Web Application Firewall')
param wafMode string = 'Prevention'

var wafPolicyName = 'waf-agw-prod-eu2-01'
var wafPolicyManagedRuleSetType = 'OWASP'
var wafPolicyManagedRuleSetVersion = '3.1'

resource wafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2020-06-01' = {
  name: wafPolicyName
  location: location
  properties: {
    policySettings: {
      mode: wafMode
      state: 'Enabled'
    }
    customRules: [
      {
        name: 'RequireCorrectfrontDoorUniqueIdHeader'
        ruleType: 'MatchRule'
        priority: 1
        action: 'Block'
        matchConditions: [
          {
            matchVariables: [
              {
                variableName: 'RequestHeaders'
                selector: 'X-Azure-FDID'
              }
            ]
            negationConditon: true
            operator: 'Equal'
            matchValues: [
              frontDoorUniqueId
            ]
          }
        ]
      }
    ]
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: wafPolicyManagedRuleSetType
          ruleSetVersion: wafPolicyManagedRuleSetVersion
        }
      ]
    }
  }
}

output wafPolicyId string = wafPolicy.id
