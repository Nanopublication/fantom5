# TwitterTrends1.rb
require 'rubygems'
require 'rest_client'

require 'rexml/document'
include REXML

url = 'http://databases.lovd.nl/whole_genome/api/rest.php/variants/FKTN/unique'

response = RestClient.get(url)

xmlfile = response.body

xmldoc = Document.new(xmlfile)


xmldoc.elements.each("feed/entry/content") {
    |e|

  variantData = e.text.split(" ")
=begin  
  # Variant database ID (This should be unique for each variant on same build)
  variantDBId = variantData[4].gsub("Variant/DBID:","")
  #DNA change
  dnaChange =  variantData[3].gsub("Variant/DNA:","")
  # Transcript ID
  transcriptIDData = variantData[1].gsub("position_mRNA:","")
  # Variant genomic position
  gPosData =  variantData[2].gsub("position_genomic:","")
=end
 
  # Variant database ID (This should be unique for each variant on same build)  
  variantDBId = "-NA-"
  # DNA change
  dnaChange =  "-NA-"
  # Trancript ID  
  transcriptID = "-NA-"
  # Variant genomic position
  gPos = "-NA-"
  # Variant template
  template = "-NA-"
  # Variant technique
  technique = "-NA-"
  # Pubmed ID to the publication where variant study is published
  pubmed = "-NA-"
  # Transcript ID data
  transcriptIDData = nil
  # Variant genomic position data
  gPosData =  nil  
 
  variantData.each { |data|
    
    if(data.include? "Variant/DBID:")
      variantDBId = data.gsub("Variant/DBID:","")
      
    elsif(data.include? "Variant/DNA:")
      dnaChange =  data.gsub("Variant/DNA:","")    
    
    elsif(data.include? "position_mRNA:")
      transcriptIDData = data.gsub("position_mRNA:","")  
      
    elsif(data.include? "position_genomic:")
      gPosData =  data.gsub("position_genomic:","")        
      
      end
  } 
  
 

  if(transcriptIDData.include? ":")
    transcriptID = transcriptIDData.split(":")[0]

  end
  

  if(gPosData.include? ":")
    gPos = gPosData.split(":")[1]

    if(dnaChange.include? "del")
      gPos = "g."+gPos+"del"
    end

    if(dnaChange.include? "dup")
      gPos = "g."+gPos+"dup"
    end

    if(dnaChange.include? ">")
      subData = dnaChange.split(">")
      firstChar = subData[0]
      lastChar = subData[1]
      gPos = "g."+gPos+firstChar[firstChar.length-1]+">"+lastChar[0]
    end

    if(dnaChange.include? "ins")
      insData = dnaChange.split("ins")
      gPos = "g."+gPos+"ins"+insData[1]
    end

  end
  
  row = "#{transcriptID}\t#{variantDBId}\t#{dnaChange}\t#{gPos}\t#{template}\t#{technique}\t#{pubmed}"

  puts row


}