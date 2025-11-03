
 //Custom Text Header //
 // ACSII slant font

// Needs to be inside <section id="login" class="shadow">
// YOU MUST ESCAPE ANY SINGLE BACKSLASHES LIKE SO: \\

let custom_text_header = `
<div class="custom-text-header"> <pre>              
 ___  ___      ________          ___      ________      _______      
|\  \|\  \    |\   ___  \       |\  \    |\   __  \    |\  ___ \     
\ \  \\\  \   \ \  \\ \  \      \ \  \   \ \  \|\  \   \ \   __/|    
 \ \  \\\  \   \ \  \\ \  \   __ \ \  \   \ \  \\\  \   \ \  \_|/__  
  \ \  \\\  \   \ \  \\ \  \ |\  \\_\  \   \ \  \\\  \   \ \  \_|\ \ 
   \ \_______\   \ \__\\ \__\\ \________\   \ \_______\   \ \_______\
    \|_______|    \|__| \|__| \|________|    \|_______|    \|_______|
 </pre> </div>
`;
document.getElementById("login").innerHTML += custom_text_header
