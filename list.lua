
local theList = {}

local placeSortedItem = function (list, item, index, moveForward, mappingFunc)end

---@param list table
---@param item any
---@param index integer
---@param moveForward? boolean
---@param mappingFunc fun(value: any): number
---@return integer
placeSortedItem = function (list, item, index, moveForward, mappingFunc)
    if #list == 0 then
        table.insert(list, item)
        return index
    else
        local currVal = mappingFunc(item)
        local prevVal = mappingFunc(list[index])

        if moveForward ~= nil then
            if (moveForward and currVal <= prevVal) or (not moveForward and currVal >= prevVal) then
                table.insert(list, index, item)
                return index
            end
        end
        
        if currVal > prevVal then
            if index == #list then
                table.insert(list, #list + 1, item)
                return index
            else
                placeSortedItem(list, item, index + 1, true, mappingFunc)
            end
        elseif currVal < prevVal then
            if index == 1 then
                table.insert(list, 1, item)
                return index
            else
                placeSortedItem(list, item, index - 1, false, mappingFunc)
            end
        end
    end
    return index
end


theList = {
    ---@param list table
    ---@param value any
    ---@return integer
    index = function (list, value)
        for i, v in ipairs(list) do
            if value == v then
                return i
            end
        end
        return -1
    end,

    ---@param list table
    copy = function (list)
        local newList = {}

        for key, value in pairs(list) do
            if type(value) == "table" then
                value = theList.copy(value)
            end
            newList[key] = value
        end

        return newList
    end,

    ---@param ... table
    ---@return table
    add = function (...)
        local lists = {...}

        local finalList = {}

        local completeIndex = 1
        for _, list in ipairs(lists) do
            local listIndex = 1
            for key, value in pairs(list) do
                if type(key) == 'number' then
                    finalList[(key - listIndex) + completeIndex] = value
                    listIndex = listIndex + 1
                else
                    finalList[key] = value
                    completeIndex = completeIndex - 1
                end
                completeIndex = completeIndex + 1
            end
        end

        return finalList
    end,

    ---@overload fun(stop: number): table
    ---@overload fun(start: number, stop: number): table
    ---@param start number
    ---@param stop number
    ---@param step number
    ---@return table
    range = function (start, stop, step)
        local list = {}

        if step ~= nil then
            for i = start, stop, step do
                list[i] = i
            end
            return list
        end

        if stop == nil then
            for i = 1, start, 1 do
                list[i] = i
            end
            return list
        else
            for i = start, stop, 1 do
                list[i + 1 - start] = i
            end
            return list
        end
        
    end,

    ---@param list table
    ---@param comprehensionFunction fun(key: any, value: any): any
    ---@return table
    comprehension = function (list, comprehensionFunction)
        local comprehensionList = {}
        
        for key, value in pairs(list) do
            table.insert(comprehensionList, comprehensionFunction(key, value))
        end

        return comprehensionList
    end,

    ---@param list table
    ---@param size? integer
    shuffle = function (list, size)
        size = size or #list

        if size > #list then
            error('The size of the new list cannot be greater than the size of the original')
        end

        local newList = {}
        local listRange = theList.range(#list)

        for _ = 1, size do
            math.randomseed(os.time() * math.random(#listRange))
            local index = listRange[math.random(#listRange)]

            table.remove(listRange, theList.index(listRange, index))
            table.insert(newList, list[index])
        end

        return newList
    end,

    ---Including both ends in the new list
    ---@param list table
    ---@param startIndex integer
    ---@param stopIndex integer
    split = function (list, startIndex, stopIndex)
        local newList = {}
        for index = startIndex, stopIndex, 1 do
            table.insert(newList, list[index])
        end

        return newList
    end,

    ---@param list table
    ---@param value any
    ---@return table
    removeAll = function (list, value)
        local newList = {}

        for key, listVal in ipairs(list) do
            if listVal ~= value then
                newList[key] = listVal
            end
        end

        return newList
    end,

    ---@param list any[]
    ---@param mappingFunc? fun(value: any): number
    ---@return table
    sort = function (list, mappingFunc)
        local sortedList = {}
        local index = 1
        
        mappingFunc = mappingFunc or function (value)
            if type(value) == "number" then
                return value
            elseif type(value) == "string" then
                return string.len(value)
            elseif type(value) == "table" then
                return #value
            else
                error("Unsupported value passed of type "..type(value))
            end
        end

        for _, value in ipairs(list) do
            index = placeSortedItem(sortedList, value, index, nil, mappingFunc)
        end    

        return sortedList
    end
}


return theList