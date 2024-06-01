local Heap = {}
Heap.__index = Heap

-- Default comparison function for min-heap
local function defaultCompare(a, b)
    return a < b
end

-- Constructor for the heap
function Heap.new(compare)
    return setmetatable({
        _data = {},
        _size = 0,
        Compare = compare or defaultCompare
    }, Heap)
end

-- Percolates up to maintain the heap property
local function percolateUp(heap, index)
    local data = heap._data
    local compare = heap.Compare
    while index > 1 do
        local parentIndex = math.floor(index / 2)
        if compare(data[index], data[parentIndex]) then
            data[index], data[parentIndex] = data[parentIndex], data[index]
            index = parentIndex
        else
            break
        end
    end
end

-- Percolates down to maintain the heap property
local function percolateDown(heap, index)
    local data = heap._data
    local compare = heap.Compare
    local size = heap._size
    while true do
        local leftIndex, rightIndex = 2 * index, 2 * index + 1
        local smallest = index

        if leftIndex <= size and compare(data[leftIndex], data[smallest]) then
            smallest = leftIndex
        end
        if rightIndex <= size and compare(data[rightIndex], data[smallest]) then
            smallest = rightIndex
        end

        if smallest ~= index then
            data[index], data[smallest] = data[smallest], data[index]
            index = smallest
        else
            break
        end
    end
end

-- Checks if the heap is empty
function Heap:empty()
    return self._size == 0
end

-- Clears the heap
function Heap:clear()
    self._data = {}
    self._size = 0
end

-- Adds an item to the heap
function Heap:push(item)
    self._size = self._size + 1
    self._data[self._size] = item
    percolateUp(self, self._size)
end

-- Removes and returns the root element of the heap
function Heap:pop()
    if self._size == 0 then
        return nil
    end
    local root = self._data[1]
    self._data[1] = self._data[self._size]
    self._data[self._size] = nil
    self._size = self._size - 1
    if self._size > 0 then
        percolateDown(self, 1)
    end
    return root
end

-- Restores the heap property
function Heap:heapify()
    for i = math.floor(self._size / 2), 1, -1 do
        percolateDown(self, i)
    end
end

return Heap

--[[ 2
    
local Heap = {}
Heap.__index = Heap

-- Default comparison function for min-heap
local function defaultCompare(a, b)
    return a < b
end

-- Constructor for the heap.
-- @param compare? Function for comparison, defining the heap property. Defaults to a min-heap.
function Heap.new(compare)
    return setmetatable({
        _data = {},
        _size = 0,
        Compare = compare or defaultCompare
    }, Heap)
end

-- Percolates up to maintain the heap property
local function percolateUp(heap, index)
    while index > 1 do
        local parentIndex = math.floor(index / 2)
        if heap.Compare(heap._data[index], heap._data[parentIndex]) then
            heap._data[index], heap._data[parentIndex] = heap._data[parentIndex], heap._data[index]
            index = parentIndex
        else
            break
        end
    end
end

-- Percolates down to maintain the heap property
local function percolateDown(heap, index)
    while true do
        local leftIndex, rightIndex = 2 * index, 2 * index + 1
        local smallest = index

        if leftIndex <= heap._size and heap.Compare(heap._data[leftIndex], heap._data[smallest]) then
            smallest = leftIndex
        end
        if rightIndex <= heap._size and heap.Compare(heap._data[rightIndex], heap._data[smallest]) then
            smallest = rightIndex
        end

        if smallest ~= index then
            heap._data[index], heap._data[smallest] = heap._data[smallest], heap._data[index]
            index = smallest
        else
            break
        end
    end
end

-- Checks if the heap is empty
function Heap:empty()
    return self._size == 0
end

-- Clears the heap
function Heap:clear()
    self._data = {}
    self._size = 0
end

-- Adds an item to the heap
function Heap:push(item)
    self._size = self._size + 1
    self._data[self._size] = item
    percolateUp(self, self._size)
end

-- Removes and returns the root element of the heap
function Heap:pop()
    if self._size == 0 then
        return nil
    end
    local root = self._data[1]
    self._data[1] = self._data[self._size]
    self._data[self._size] = nil
    self._size = self._size - 1
    if self._size > 0 then
        percolateDown(self, 1)
    end
    return root
end

-- Restores the heap property
function Heap:heapify()
    for i = math.floor(self._size / 2), 1, -1 do
        percolateDown(self, i)
    end
end

return Heap
]]

--------------------------------------------

--[[ 1
local Heap = {}
Heap.__index = Heap

-- Default comparison function for min-heap
local function defaultCompare(a, b)
    return a < b
end

-- Constructor for the heap.
-- @param compare? Function for comparison, defining the heap property. Defaults to a min-heap.
function Heap.new(compare)
    return setmetatable({
        _data = {},
        _size = 0,
        Compare = compare or defaultCompare
    }, Heap)
end

-- Percolates up to maintain the heap property
local function percolateUp(heap, index)
    while index > 1 do
        local parentIndex = math.floor(index / 2)
        if heap.Compare(heap._data[index], heap._data[parentIndex]) then
            heap._data[index], heap._data[parentIndex] = heap._data[parentIndex], heap._data[index]
            index = parentIndex
        else
            break
        end
    end
end

-- Percolates down to maintain the heap property
local function percolateDown(heap, index)
    while true do
        local leftIndex, rightIndex = 2 * index, 2 * index + 1
        local smallest = index

        if leftIndex <= heap._size and heap.Compare(heap._data[leftIndex], heap._data[smallest]) then
            smallest = leftIndex
        end
        if rightIndex <= heap._size and heap.Compare(heap._data[rightIndex], heap._data[smallest]) then
            smallest = rightIndex
        end

        if smallest ~= index then
            heap._data[index], heap._data[smallest] = heap._data[smallest], heap._data[index]
            index = smallest
        else
            break
        end
    end
end

-- Checks if the heap is empty
function Heap:empty()
    return self._size == 0
end

-- Clears the heap
function Heap:clear()
    self._data = {}
    self._size = 0
end

-- Adds an item to the heap
function Heap:push(item)
    self._size = self._size + 1
    self._data[self._size] = item
    percolateUp(self, self._size)
end

-- Removes and returns the root element of the heap
function Heap:pop()
    if self._size == 0 then
        return nil
    end
    local root = self._data[1]
    self._data[1] = self._data[self._size]
    self._data[self._size] = nil
    self._size = self._size - 1
    if self._size > 0 then
        percolateDown(self, 1)
    end
    return root
end

-- Restores the heap property
function Heap:heapify()
    for i = math.floor(self._size / 2), 1, -1 do
        percolateDown(self, i)
    end
end

return Heap
]]