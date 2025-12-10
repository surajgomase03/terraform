provider "aws" {
    alias = "east"
    region = "us-east-1"
  
}
#use alias for multiple regions 
provider "aws" {
    alias = "west"
    region = "us-west-2"

  
}

provider "azurerm" {
   
}