" make sure we only load this plugin a single time
if exists("loaded_filecycle")
    finish
endif
let loaded_filecycle = 1

" find the element in extensionList that has the longest suffix
" match against filename.
" return -1 if no item matches
function! <SID>DetermineBaseName(filename, extensionList)
    let shortestIdx = -1 
    let shortestLength = 99999

    let n = 0
    while(n < len(a:extensionList))
        let extension = a:extensionList[n]
        let trial = substitute(a:filename, extension.'$', '', '')
        if(trial != a:filename)
            if(shortestIdx == -1 || strlen(trial) < shortestLength)
                let shortestLength = strlen(trial)
                let shortestIdx = n
            endif
        endif
        let n = n + 1
    endwhile

    return shortestIdx
endfunction

" 
function! CycleFiles(doSplit, include_inline)
  let currentFile = expand("%:p")
  let extensionList = ["_inline.h", "_inline.cpp", ".cpp", ".c", ".h", ".hpp", ".inc"]
  let currentIdx = <SID>DetermineBaseName(currentFile, extensionList)

  if(currentIdx == -1)
    echo "Unhandled file extension"  
  else 
    let baseName = substitute(currentFile, extensionList[currentIdx] . "$", "", "")
    let bestScore = 0
    let bestFile = ''

    let n = (currentIdx + 1) % len(extensionList)
    while(n != currentIdx)
        let filename = baseName . extensionList[n]
        let score = <SID>BufferOrFileExists(filename)
        if(a:include_inline == 0 && match(extensionList[n], "_inline.") == 0)
            let score = -1
        endif

        if(score > bestScore)
            let bestFile = filename
            let bestScore = 9999
        endif
        let n = (n + 1) % len(extensionList)
    endwhile

    if(bestFile == '')
        echo "No alternate file located"
    else
        call <SID>FindOrCreateBuffer(bestFile, a:doSplit)
    endif
  endif
endfunction

comm! -nargs=? -bang A  call CycleFiles('n<bang>', 0)
comm! -nargs=? -bang AI call CycleFiles('n<bang>', 1)
comm! -nargs=? -bang AH call CycleFiles('h<bang>', 1)
comm! -nargs=? -bang AV call CycleFiles('v<bang>', 1)

" stolen
function! <SID>FindOrCreateBuffer(filename, doSplit)
  " Check to see if the buffer is already open before re-opening it.
  let bufName = bufname(a:filename)
  let bufFilename = fnamemodify(a:filename, ":t")

  if (bufName == "")
     let bufName = bufname(bufFilename)
  endif

  if (bufName != "")
     let tail = fnamemodify(bufName, ":t")
     if (tail != bufFilename)
        let bufName = ""
     endif
  endif

  let splitType = a:doSplit[0]
  let bang = a:doSplit[1]
  if (bufName == "")
     " Buffer did not exist....create it
     let v:errmsg=""
     if (splitType == "h")
        silent! execute ":split" . bang . " " . a:filename
     elseif (splitType == "v")
        silent! execute ":vsplit" . bang . " " . a:filename
     else
        silent! execute ":e" . bang . " " . a:filename
     endif
     if (v:errmsg != "")
        echo v:errmsg
     endif
  else
     " Buffer was already open......check to see if it is in a window
     let bufWindow = bufwinnr(bufName)
     if (bufWindow == -1) 
        " Buffer was not in a window so open one
        let v:errmsg=""
        if (splitType == "h")
           silent! execute ":sbuffer" . bang . " " . bufName
        elseif (splitType == "v")
           silent! execute ":vert sbuffer " . bufName
        else
           silent! execute ":buffer" . bang . " " . bufName
        endif
        if (v:errmsg != "")
           echo v:errmsg
        endif
     else
        " Buffer is already in a window so switch to the window
        execute bufWindow."wincmd w"
        if (bufWindow != winnr()) 
           " something wierd happened...open the buffer
           let v:errmsg=""
           if (splitType == "h")
              silent! execute ":split" . bang . " " . bufName
           elseif (splitType == "v")
              silent! execute ":vsplit" . bang . " " . bufName
           else
              silent! execute ":e" . bang . " " . bufName
           endif
           if (v:errmsg != "")
              echo v:errmsg
           endif
        endif
     endif
  endif
endfunction

function! <SID>BufferOrFileExists(fileName)
   let result = 0
   let bufName = fnamemodify(a:fileName,":t")
   let memBufName = bufname(bufName)
   if (memBufName != "")
      let memBufBasename = fnamemodify(memBufName, ":t")
      if (bufName == memBufBasename)
         let result = 2
      endif
   endif

   if (!result)
      let result  = bufexists(bufName) || bufexists(a:fileName) || filereadable(a:fileName)
   endif
   return result
endfunction

