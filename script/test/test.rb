string = "##ColumnVariables[tpm.xeroderma%20pigentosum%20b%20cell%20line%3aXPL%2017.CNhs11813.10563-108A5]=TPM (tags per million) of xeroderma pigentosum b cell line:XPL 17.CNhs11813.10563-108A5
"  
phone_re = /CNhs(.*\])/  

m = phone_re.match(string)

puts m