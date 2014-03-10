```
  
  ############################ 
  #           #  #           #  
   #          #  #          #   
    #        #    #        #    
    #       ##    ##       #    
     #      #      #      #     
     #     #        #     #     
      #    #        #    #      
      ##  #          #  ##      
       # ##          ## #       
        ##            ##        
        #   Alchemist  #        
        ##   Server   ##        
       # ##          ## #       
      ##  #          #  ##      
      #    #        #    #      
     #     #        #     #     
     #      #      #      #     
    #       ##    ##       #    
    #        #    #        #    
   #          #  #          #   
  #           #  #           #  
  ############################ 


```

# What is Alchemist?

Alchemist Server is a light-weight Sinatra app, that is designed to connect 4 major components:

+ Collins Source Of Truth
+ Alchemy Linux
+ Alchemy Spells
+ iPXE

As such, it's pretty closely coupled to these other projects. Alchemist is contacted by iPXE when a server boots via PXE. It will see what it knows about the server in Collins, then make a decision about what the server should do. Examples of such decisions might be:

+ Already bootstrapped? Continue with BIOS boot
+ New hardware? Send Alchemy Linux, with Burnin and Bootstrapp spells, and tell Collins we've got some fresh meat.
+ Collins knows about it, and has a specific job in mind? Send the spell for that job.

Alchemist might be thought of as a lightweight version of Cobbler (from what I'm told, but it's a pretty superficial comparison). Alchemist was inspired by "Phil" from tumblr.

# Technical details

## Architecture

Alchemist listens on HTTP for requests from servers booting through iPXE. A few identifying details are passed to Alchemist, which it then uses to query Collins server through it's HTTP API. It then makes a decision about what to do with the server, and then consults it's Spellbook to send an appropriate iPXE configuration.

If the spell involves booting Alchemy Linux, Alchemy linux will call home and tell Alchemist how it's doing once in a while (assuming the spell dispatched tells it to do so). 
