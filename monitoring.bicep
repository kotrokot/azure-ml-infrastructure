@maxLength(14)
@description('Suffix to the names of the resources.')
param resourceNameSuffix string

var config = {
}
var tags = {
  resourceSuffix: resourceNameSuffix
}

/*
It's a blank module. Dashboards and Azure monitoring Alert Rules should be here.
*/
