open ThreeDSUtils

let defaultSurcharge: AdvancedRoutingTypes.surchargeDetailsType = {
  surcharge: {
    \"type": "rate",
    value: {
      percentage: 0.0,
    },
  },
  tax_on_surcharge: {
    percentage: 0.0,
  },
}

let surchargeRules: AdvancedRoutingTypes.rule = {
  name: "rule_1",
  connectorSelection: {
    surcharge_details: defaultSurcharge->Nullable.make,
  },
  statements: statementObject,
}

let buildInitialSurchargeValue: threeDsRoutingType = {
  name: `Surcharge -${RoutingUtils.getCurrentUTCTime()}`,
  description: `This is a new Surcharge created at ${RoutingUtils.currentTimeInUTC}`,
  algorithm: {
    rules: [surchargeRules],
    defaultSelection: {
      surcharge_details: Nullable.null,
    },
    metadata: JSON.Encode.null,
  },
}

let buildSurchargePayloadBody = values => {
  open LogicUtils
  let valuesDict = values->getDictFromJsonObject
  let algorithmDict = valuesDict->getDictfromDict("algorithm")
  let rulesDict = algorithmDict->getArrayFromDict("rules", [])

  let modifiedRules = rulesDict->AdvancedRoutingUtils.generateRule
  {
    "name": valuesDict->getString("name", ""),
    "algorithm": {
      "defaultSelection": algorithmDict->getJsonObjectFromDict("defaultSelection"),
      "rules": modifiedRules,
      "metadata": Dict.make()->JSON.Encode.object,
    },
    "merchant_surcharge_configs": {
      "show_surcharge_breakup_screen": true,
    },
  }
}

let getTypedSurchargeConnectorSelection = ruleDict => {
  open LogicUtils
  let connectorsDict = ruleDict->getDictfromDict("connectorSelection")

  AdvancedRoutingUtils.getDefaultSelection(connectorsDict)
}

let ruleInfoTypeMapper: Dict.t<JSON.t> => AdvancedRoutingTypes.algorithmData = json => {
  open LogicUtils
  let rulesArray = json->getArrayFromDict("rules", [])

  let defaultSelection = json->getDictfromDict("defaultSelection")

  let rulesModifiedArray = rulesArray->Array.map(rule => {
    let ruleDict = rule->getDictFromJsonObject

    let connectorSelection = getTypedSurchargeConnectorSelection(ruleDict)
    let ruleName = ruleDict->getString("name", "")

    let eachRule: AdvancedRoutingTypes.rule = {
      name: ruleName,
      connectorSelection,
      statements: AdvancedRoutingUtils.conditionTypeMapper(
        ruleDict->getArrayFromDict("statements", []),
      ),
    }
    eachRule
  })

  {
    rules: rulesModifiedArray,
    defaultSelection: AdvancedRoutingUtils.getDefaultSelection(defaultSelection),
    metadata: json->getJsonObjectFromDict("metadata"),
  }
}

let getDefaultSurchargeType = surchargeType => {
  surchargeType->Option.getOr(Nullable.null)->Nullable.toOption->Option.getOr(defaultSurcharge)
}

let validateSurchargeRate = ruleDict => {
  let connectorSelection = ruleDict->getTypedSurchargeConnectorSelection

  let surchargeType = getDefaultSurchargeType(connectorSelection.surcharge_details)
  let surchargeValuePercent = surchargeType.surcharge.value.percentage->Option.getOr(0.0)
  let surchargeValueAmount = surchargeType.surcharge.value.amount->Option.getOr(0.0)
  let isSurchargeAmountValid = if surchargeType.surcharge.\"type" == "rate" {
    surchargeValuePercent == 0.0 || surchargeValuePercent > 100.0
  } else {
    surchargeValueAmount == 0.0
  }

  !isSurchargeAmountValid
}

let validateConditionsForSurcharge = dict => {
  let conditionsArray = dict->LogicUtils.getArrayFromDict("statements", [])

  conditionsArray->Array.every(value => {
    value->RoutingUtils.validateConditionJson(["comparison", "lhs"])
  }) && validateSurchargeRate(dict)
}
