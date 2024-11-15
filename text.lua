
---@param x number Center x positon
---@param y number Center x positon
---@param size string h1, h2, h3, h4, h5, h6, p
---@param color table
---@param wrapWidth? number Wrap amount(optional)
---@param align? string On which axis should it be aligned to (optional)
---@return table # A class-like table
local function Text(x, y, size, color, wrapWidth, align)
    return {
        x = x,
        y = y,
        text = '',
        size = size, 
        color = color,
        align = align or 'left',
        wrapWidth = wrapWidth or love.graphics.getWidth(),

        ---comment
        ---@param x_dir integer
        ---@param y_dir integer
        ---@param by? number
        scroll = function (self, x_dir, y_dir, by)
            local scrollBy = by or Fonts[self.size]:getHeight()
            self.x = self.x + (scrollBy * x_dir)
            self.y = self.y + (scrollBy * y_dir)
        end,
        
        ---@param text string
        setText = function (self, text)
            self.text = text            
        end
        ,

        write = function (self)
            love.graphics.setColor(self.color.r or self.color[1], self.color.g or self.color[2], self.color.b or self.color[3])
            love.graphics.setFont(Fonts[self.size])
            love.graphics.printf(self.text, self.x, self.y, self.wrapWidth, self.align)
            love.graphics.setFont(Fonts['p'])
        end,
    }
end

return Text
