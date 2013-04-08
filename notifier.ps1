function Main(){
	LoadConfig("app.config");

	# Load the Notification XML
	$doc = [xml](get-content syndicationlist.xml);

	$docNsMgr = new-object Xml.XmlNamespaceManager $doc.NameTable

	$docNsMgr.AddNamespace("catalog", "http://www.cdc.gov/socialmedia/syndication/SyndicationCatalog.xsd");
	$docNsMgr.AddNamespace("content", "http://www.cdc.gov/socialmedia/syndication/SyndicationContent.xsd");

	# Make a copy of the outermost Catalog node and CatalogSource.
	# We'll then copy individual the CatalogItem nodes one at a time,
	# each replacing the one before.
	$noticeEnvelope = $doc.DocumentElement.CloneNode($False);
	$catalogSource = $doc.SelectSingleNode("//catalog:CatalogSource", $docNsMgr);
	if($catalogSource -eq $null) {echo "Error: Cannot locate CatalogSource element.";}
	$bucket = $noticeEnvelope.AppendChild( $catalogSource );

	# Build notification messages for each catalog item.
	$catalogItems = $doc.SelectNodes("//catalog:CatalogItem", $docNsMgr);
	$catalogItems | ForEach-Object {

		$bucket = $noticeEnvelope.AppendChild($_);
		
		$noticeEnvelope.OuterXml | Out-file (".\DebugOut\" + $_.CatalogId + ".xml") -Encoding "UTF8";

		$bucket = $noticeEnvelope.RemoveChild($_);
	}
}

# Sends and HTTP POST request to the specified URL.
#
# $targetUrl - URL to send the post to.
# $data - data to transmit with the post.
function Execute-HTTPPostCommand($targetUrl, $data) {

    $webRequest = [System.Net.WebRequest]::Create($targetUrl)
    $webRequest.ContentType = "text/html"
    $PostStr = [System.Text.Encoding]::UTF8.GetBytes($data)
    $webrequest.ContentLength = $PostStr.Length
    $webRequest.ServicePoint.Expect100Continue = $false

    $webRequest.PreAuthenticate = $true
    $webRequest.Method = "POST"

    $requestStream = $webRequest.GetRequestStream()
    $requestStream.Write($PostStr, 0,$PostStr.length)
    $requestStream.Close()

    [System.Net.WebResponse] $resp = $webRequest.GetResponse();
    $rs = $resp.GetResponseStream();
    [System.IO.StreamReader] $sr = New-Object System.IO.StreamReader -argumentList $rs;
    [string] $results = $sr.ReadToEnd();
	$rs.Close();
	$resp.Close();
	
    return $results;
}

# Loads configuration data in a format similar to that used by .Net.
# Parses through an appSettings section, looking for keys added with an <add> element
# and stores values in a hashtable with lookups based on the key attribute.
#
# Based on code from http://rkeithhill.wordpress.com/2006/06/01/creating-and-using-a-configuration-file-for-your-powershell-scripts/
function LoadConfig(){
    param($path = $(throw "You must specify a config file"))

    $global:appSettings = @{}
    $config = [xml](get-content $path)
    foreach ($addNode in $config.configuration.appsettings.add) {
        if ($addNode.Value.Contains(�,�)) {
            # Array case
            $value = $addNode.Value.Split(�,�)
            for ($i = 0; $i -lt $value.length; $i++) { 
                $value[$i] = $value[$i].Trim() 
            }
        }
        else {
            # Scalar case
            $value = $addNode.Value
        }
        $global:appSettings.Add($addNode.Key, $value)
    }
}


Main;