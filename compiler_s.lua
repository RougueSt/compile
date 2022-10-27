-- this resource based on IIYAMA compiler-- 
local ignoreList = {
	["admin"] = true,
	["admin2"] = true,
	["runcode"] = true,
	["AUTOCompiler"] = true,
	["hedit"] = true,
	["dgs"] = true
}


local allowToStart = {}
local fetchedFiles = {}
local parsingInProgress = {}


function getScriptsCount(meta) 
	local metaNotes = xmlNodeGetChildren(meta) 
	local count = 0
	
	for i=1, #metaNotes do 
		local metaNote = metaNotes[i]
		local scriptName = xmlNodeGetAttribute(metaNote, "src") 
		if scriptName then
			if xmlNodeGetName(metaNote) == "script" then
				count = count + 1 
			end
		end
	end
	-- outputDebugString("meta notes: "..#metaNotes)
	-- outputDebugString("meta script count: "..count)
	return count
end

function startIfCan(resName)
	if fetchedFiles[resName] then 
		if fetchedFiles[resName]["loaded"] == fetchedFiles[resName]["count"] then
			allowToStart[resName] = true
		end
	end
	-- outputDebugString("starting is allowed: "..tostring(allowToStart[resName]))
	if not parsingInProgress[resName] then 
		-- outputDebugString("starting because not parsing")
		startResource(getResourceFromName(resName),true)
	end
	
end
function sendScript(savePath,scriptData,resName) 
	fetchRemote( "http://luac.mtasa.com/?compile=1&debug=0&obfuscate=3",  
	function(data)  
		local newscriptFile = fileCreate ( savePath ) 
		if newscriptFile then 
			fileWrite(newscriptFile, data)  
			fileFlush(newscriptFile) 
			fileClose(newscriptFile) 
		end 
		if fetchedFiles[resName] then 
			fetchedFiles[resName]["loaded"] = fetchedFiles[resName]["loaded"] + 1
		end
		startIfCan(resName)
	end, scriptData , true )
end

function compileResource (resourceName)
    if getResourceFromName ( resourceName ) then 
		if not hasObjectPermissionTo ( getThisResource (), "function.fetchRemote", false ) then
			outputConsole("Require fetchRemote to compiling this resource!")
		else
			local meta = xmlLoadFile(":" .. resourceName .. "/meta.xml")
			parsingInProgress[resourceName] = true
			fetchedFiles[resourceName] = {}
			fetchedFiles[resourceName]["loaded"] = 0
			fetchedFiles[resourceName]["count"] = getScriptsCount(meta)
			--open file handler
			local hashFile = fileOpen("hash.json")
			--read file and convert from json to table
			local hashTable
			if fileGetSize(hashFile) == 0 then 
				hashTable = {}
			else
				hashTable = fromJSON(fileRead( hashFile,fileGetSize(hashFile))) or {}
			end
			fileClose(hashFile)

            if meta then 
                local folderName = ":"..resourceName.."/"
				if meta then 
					local metaNotes = xmlNodeGetChildren(meta) 
					for i=1, #metaNotes do 
						local metaNote = metaNotes[i]
						local scriptName = xmlNodeGetAttribute(metaNote, "src") 
						if scriptName then
							if xmlNodeGetName(metaNote) == "script" then 
								outputDebugString(tostring(scriptName) .. " "..tostring(xmlNodeGetName(metaNote)))
								if scriptName and scriptName ~= "" then 
									local FROM = ":" .. resourceName .. "/" .. scriptName 
									FROM = FROM:gsub(".luac",".lua")
                                    --transforms .lua to .luac
                                    local TO = FROM .. "c"
									-- local TO = folderName .. "/" .. scriptName .. "c" 
									 
									local scriptFile = fileOpen(FROM) 
									local scriptData = fileRead(scriptFile, fileGetSize ( scriptFile ))
									local scriptHash = hash("md5",scriptData)
									
									-- local isAllowedToCompile = false

									local previousHash = hashTable[FROM]
									
									-- outputDebugString("pHash: "..previousHash)
									-- outputDebugString("sHash: "..scriptHash)
									if previousHash ~= scriptHash then
										sendScript(TO,scriptData,resourceName)
									else
										fetchedFiles[resourceName]["loaded"] = fetchedFiles[resourceName]["loaded"] + 1
										outputDebugString("[Compiler] File not changed, skipping compilation of file: "..FROM)
										-- outputDebugString("2")
										startIfCan(resourceName)
									end
									hashTable[FROM] = scriptHash
									fileClose(scriptFile) 
								end 
							-- else 
							-- 	local fileName = xmlNodeGetAttribute(metaNote, "src") 
							-- 	if fileName then 
							-- 		fileCopy (":" .. resourceName .. "/" .. fileName, folderName .. "/" .. fileName, true ) 
							-- 	end 
							end
						end
					end 
					local newMetaNotes = xmlNodeGetChildren(meta) 
					for i=1, #newMetaNotes do 
						local newMetaNote = newMetaNotes[i] 
						if xmlNodeGetName(newMetaNote) == "script" then 
							
							local scriptName = xmlNodeGetAttribute(newMetaNote, "src") 
							scriptName = scriptName:gsub(".luac",".lua")
							if not string.match(scriptName, "compiler.lua") then
								if scriptName and scriptName ~= "" then 
									xmlNodeSetAttribute ( newMetaNote, "src", scriptName .. "c" ) 
								end 
							else
								xmlDestroyNode(newMetaNote)
							end
						end 
					end 
					xmlSaveFile(meta) 
					xmlUnloadFile(meta) 
				end 
				-- xmlUnloadFile(meta) 
				hashFile = fileCreate("hash.json")
				fileWrite(hashFile,toJSON(hashTable))
				fileFlush(hashFile)
				fileClose(hashFile)
				parsingInProgress[resourceName] = nil
			end 
		end
	end 
	return true
end
function resourceStarting ( res )
	local resName = getResourceName( res)
	if ignoreList[resName] then return end
	local allow = allowToStart[resName] or false
	if not allow then 
		outputDebugString("[Compiler] started compiling "..resName)
		local result = compileResource(resName)
		if result then 
			if allowToStart[resName] then 
				startIfCan(resName) 
				allow = allowToStart[resName] or false
			end
		end
	end

	if not allow then cancelEvent(true,"Waiting for compiling") return end
	refreshResources(false,res)
	allowToStart[resName] = nil
	fetchedFiles[resName] = nil
	outputDebugString("[Compiler] starting resource "..resName)
end
addEventHandler ( "onResourcePreStart", getRootElement(), resourceStarting )