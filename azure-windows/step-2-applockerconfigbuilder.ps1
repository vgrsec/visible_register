<# 
Author:         VGR
Date:           20180602
Script:         step-2-applockerconfigbuilder.ps1
Version:        n/a 
Twitter:        @VGRSEC
#> 

$csvfile = ".\csv\step-2-whitelist.csv"
$xmlfile = ".\windows-applocker\default.xml"
$xmldoc = [System.Xml.XmlDocument](Get-Content $xmlfile)



#$appx_template = ".\windows-applocker\rulecollection-appx-template.xml"
#$dll_template = ".\windows-applocker\rulecollection-dll-template.xml"
#$exe_template = ".\windows-applocker\rulecollection-exe-template.xml"
#$msi_template = ".\windows-applocker\rulecollection-msi-template.xml"
#$script_template = ".\windows-applocker\rulecollection-script-template.xml"

Clear-Host

# Ensure the csv exists in the correct directory

if (!(Test-Path $csvfile)) {
    Write-Warning "No applications, dlls, or installers will be whitelisted. `n$csvfile not found"
    exit
  }
else {
    Write-Host "The following will be added to the AppLocker Whitelist Template" -ForegroundColor Green
    Import-Csv $csvfile | Format-Table
}

# Confirm with the user that the csv contains the expected certificates to whitelist.
`
Write-Host "Is this accurate?" -ForegroundColor Yellow
$LoginAzureAccount = Read-Host " ( y / n ) " 
Switch ($LoginAzureAccount) 
 { 
   Y {Write-Host "Starting Script"} 
   N {Write-Warning "Please update $csvfile and run this script again"; exit} 
 } 

$csvfile = Import-csv $csvfile


ForEach ($row in $csvfile) {
  if ($row.AppType -eq "APPX") {
    
    $certificate = $row.Packaged_Application_Certificate
    
    $newruleguid=New-Guid

    $PATH = "$PWD\windows-applocker\default.xml"
    $XML = [xml](Get-Content -path $PATH)
    
    $NSMGR = New-Object System.Xml.XmlNamespaceManager($XML.NameTable)
    $NSMGR.AddNamespace("ns", $XML.DocumentElement.NamespaceURI)
    
    $rulecollectionparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Appx']", $NSMGR)
    $filepublisherrulechild = $XML.CreateElement("FilePublisherRule")
    $filepublisherrulechild.SetAttribute("Id", "$newruleguid")
    $filepublisherrulechild.SetAttribute("Name", "Signed by $certificate")
    $filepublisherrulechild.SetAttribute("Description", "")
    $filepublisherrulechild.SetAttribute("UserOrGroupSid", "S-1-1-0")
    $filepublisherrulechild.SetAttribute("Action", "Allow")
    $rulecollectionparent.AppendChild($filepublisherrulechild)
    
    $filepublisherruleparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Appx']/FilePublisherRule[@Id='$newruleguid']", $NSMGR)
    $conditionschild = $XML.CreateElement("Conditions")
    $filepublisherruleparent.AppendChild($conditionschild)
    
    $conditionsparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Appx']/FilePublisherRule[@Id='$newruleguid']/Conditions", $NSMGR)
    $filepublisherconditionchild = $XML.CreateElement("FilePublisherCondition")
    $filepublisherconditionchild.SetAttribute("PublisherName", "$certificate")
    $filepublisherconditionchild.SetAttribute("ProductName", "*")
    $filepublisherconditionchild.SetAttribute("BinaryName", "*")
    $conditionsparent.AppendChild($filepublisherconditionchild)
    
    $filepublisherconditionparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Appx']/FilePublisherRule[@Id='$newruleguid']/Conditions/FilePublisherCondition", $NSMGR)
    $binaryversionrangechild = $XML.CreateElement("BinaryVersionRange")
    $binaryversionrangechild.SetAttribute("LowSection", "*")
    $binaryversionrangechild.SetAttribute("HighSection", "*")
    $filepublisherconditionparent.AppendChild($binaryversionrangechild)
    
    $XML.save("$PATH")
    

  } Else {
  }
}

ForEach ($row in $csvfile) {
  if ($row.AppType -eq "DLL") {

    $certificate = $row.Certificate
    
    $newruleguid=New-Guid

    $PATH = "$PWD\windows-applocker\default.xml"
    $XML = [xml](Get-Content -path $PATH)
    
    $NSMGR = New-Object System.Xml.XmlNamespaceManager($XML.NameTable)
    $NSMGR.AddNamespace("ns", $XML.DocumentElement.NamespaceURI)
    
    $rulecollectionparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Dll']", $NSMGR)
    $filepublisherrulechild = $XML.CreateElement("FilePublisherRule")
    $filepublisherrulechild.SetAttribute("Id", "$newruleguid")
    $filepublisherrulechild.SetAttribute("Name", "Signed by $certificate")
    $filepublisherrulechild.SetAttribute("Description", "")
    $filepublisherrulechild.SetAttribute("UserOrGroupSid", "S-1-1-0")
    $filepublisherrulechild.SetAttribute("Action", "Allow")
    $rulecollectionparent.AppendChild($filepublisherrulechild)
    
    $filepublisherruleparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Dll']/FilePublisherRule[@Id='$newruleguid']", $NSMGR)
    $conditionschild = $XML.CreateElement("Conditions")
    $filepublisherruleparent.AppendChild($conditionschild)
    
    $conditionsparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Dll']/FilePublisherRule[@Id='$newruleguid']/Conditions", $NSMGR)
    $filepublisherconditionchild = $XML.CreateElement("FilePublisherCondition")
    $filepublisherconditionchild.SetAttribute("PublisherName", "$certificate")
    $filepublisherconditionchild.SetAttribute("ProductName", "*")
    $filepublisherconditionchild.SetAttribute("BinaryName", "*")
    $conditionsparent.AppendChild($filepublisherconditionchild)
    
    $filepublisherconditionparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Dll']/FilePublisherRule[@Id='$newruleguid']/Conditions/FilePublisherCondition", $NSMGR)
    $binaryversionrangechild = $XML.CreateElement("BinaryVersionRange")
    $binaryversionrangechild.SetAttribute("LowSection", "*")
    $binaryversionrangechild.SetAttribute("HighSection", "*")
    $filepublisherconditionparent.AppendChild($binaryversionrangechild)
    
    $XML.save("$PATH")
    
  } Else {
  }
}

ForEach ($row in $csvfile) {
  if ($row.AppType -eq "EXE") {

    $certificate = $row.Certificate
    
    $newruleguid=New-Guid

    $PATH = "$PWD\windows-applocker\default.xml"
    $XML = [xml](Get-Content -path $PATH)
    
    $NSMGR = New-Object System.Xml.XmlNamespaceManager($XML.NameTable)
    $NSMGR.AddNamespace("ns", $XML.DocumentElement.NamespaceURI)
    
    $rulecollectionparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Exe']", $NSMGR)
    $filepublisherrulechild = $XML.CreateElement("FilePublisherRule")
    $filepublisherrulechild.SetAttribute("Id", "$newruleguid")
    $filepublisherrulechild.SetAttribute("Name", "Signed by $certificate")
    $filepublisherrulechild.SetAttribute("Description", "")
    $filepublisherrulechild.SetAttribute("UserOrGroupSid", "S-1-1-0")
    $filepublisherrulechild.SetAttribute("Action", "Allow")
    $rulecollectionparent.AppendChild($filepublisherrulechild)
    
    $filepublisherruleparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Exe']/FilePublisherRule[@Id='$newruleguid']", $NSMGR)
    $conditionschild = $XML.CreateElement("Conditions")
    $filepublisherruleparent.AppendChild($conditionschild)
    
    $conditionsparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Exe']/FilePublisherRule[@Id='$newruleguid']/Conditions", $NSMGR)
    $filepublisherconditionchild = $XML.CreateElement("FilePublisherCondition")
    $filepublisherconditionchild.SetAttribute("PublisherName", "$certificate")
    $filepublisherconditionchild.SetAttribute("ProductName", "*")
    $filepublisherconditionchild.SetAttribute("BinaryName", "*")
    $conditionsparent.AppendChild($filepublisherconditionchild)
    
    $filepublisherconditionparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Exe']/FilePublisherRule[@Id='$newruleguid']/Conditions/FilePublisherCondition", $NSMGR)
    $binaryversionrangechild = $XML.CreateElement("BinaryVersionRange")
    $binaryversionrangechild.SetAttribute("LowSection", "*")
    $binaryversionrangechild.SetAttribute("HighSection", "*")
    $filepublisherconditionparent.AppendChild($binaryversionrangechild)
    
    $XML.save("$PATH")
    

  } Else {
  }
}


<#
$newruleguid=New-Guid

$PATH = "$PWD\windows-applocker\default.xml"
$XML = [xml](Get-Content -path $PATH)

$NSMGR = New-Object System.Xml.XmlNamespaceManager($XML.NameTable)
$NSMGR.AddNamespace("ns", $XML.DocumentElement.NamespaceURI)

$rulecollectionparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Exe']", $NSMGR)
$filepublisherrulechild = $XML.CreateElement("FilePublisherRule")
$filepublisherrulechild.SetAttribute("Id", "$newruleguid")
$filepublisherrulechild.SetAttribute("Name", "Signed by $FileCertificate")
$filepublisherrulechild.SetAttribute("UserOrGroupSid", "S-1-1-0")
$filepublisherrulechild.SetAttribute("Action", "Allow")
$rulecollectionparent.AppendChild($filepublisherrulechild)

$filepublisherruleparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Exe']/FilePublisherRule[@Id='$newruleguid']", $NSMGR)
$conditionschild = $XML.CreateElement("Conditions")
$filepublisherruleparent.AppendChild($conditionschild)

$conditionsparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Exe']/FilePublisherRule[@Id='$newruleguid']/Conditions", $NSMGR)
$filepublisherconditionchild = $XML.CreateElement("FilePublisherCondition")
$filepublisherconditionchild.SetAttribute("PublisherName", "$FileCertificate")
$filepublisherconditionchild.SetAttribute("ProductName", "*")
$filepublisherconditionchild.SetAttribute("BinaryName", "*")
$conditionsparent.AppendChild($filepublisherconditionchild)

$filepublisherconditionparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Exe']/FilePublisherRule[@Id='$newruleguid']/Conditions/FilePublisherCondition", $NSMGR)
$binaryversionrangechild = $XML.CreateElement("BinaryVersionRange")
$binaryversionrangechild.SetAttribute("LowSection", "*")
$binaryversionrangechild.SetAttribute("HighSection", "*")
$filepublisherconditionparent.AppendChild($binaryversionrangechild)

$XML.save("$PATH")#>

<#
 $xmldoc | Select-XML -XPath "//AppLockerPolicy/RuleCollection[@Type='Appx']" | Select-Object -ExpandProperty Node


$newruleguid=New-Guid

$PATH = "$PWD\windows-applocker\default.xml"
$XML = [xml](Get-Content -path $PATH)

$NSMGR = New-Object System.Xml.XmlNamespaceManager($XML.NameTable)
$NSMGR.AddNamespace("ns", $XML.DocumentElement.NamespaceURI)

$rulecollectionparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Appx']", $NSMGR)
$filepublisherrulechild = $XML.CreateElement("FilePublisherRule")
$filepublisherrulechild.SetAttribute("Id", "$newruleguid")
$filepublisherrulechild.SetAttribute("Name", "Signed by VGRSEC")
$filepublisherrulechild.SetAttribute("UserOrGroupSid", "S-1-1-0")
$filepublisherrulechild.SetAttribute("Action", "Allow")
$rulecollectionparent.AppendChild($filepublisherrulechild)

$filepublisherruleparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Appx']/FilePublisherRule[@Id='$newruleguid']", $NSMGR)
$conditionschild = $XML.CreateElement("Conditions")
$filepublisherruleparent.AppendChild($conditionschild)

$conditionsparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Appx']/FilePublisherRule[@Id='$newruleguid']/Conditions", $NSMGR)
$filepublisherconditionchild = $XML.CreateElement("FilePublisherCondition")
$filepublisherconditionchild.SetAttribute("PublisherName", "CN=LOLHAI")
$filepublisherconditionchild.SetAttribute("ProductName", "*")
$filepublisherconditionchild.SetAttribute("BinaryName", "*")
$conditionsparent.AppendChild($filepublisherconditionchild)

$filepublisherconditionparent = $XML.selectSingleNode("//AppLockerPolicy/RuleCollection[@Type='Appx']/FilePublisherRule[@Id='$newruleguid']/Conditions/FilePublisherCondition", $NSMGR)
$binaryversionrangechild = $XML.CreateElement("BinaryVersionRange")
$binaryversionrangechild.SetAttribute("LowSection", "*")
$binaryversionrangechild.SetAttribute("HighSection", "*")
$filepublisherconditionparent.AppendChild($binaryversionrangechild)

$XML.save("$PATH")
#>