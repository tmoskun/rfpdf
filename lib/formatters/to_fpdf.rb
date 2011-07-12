# Copyright (c) 2009 Tanya Moskun
#
# The MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'yaml'
module PDF_Formatter
  
  COLORS = YAML::load(File.read(File.dirname(__FILE__)+'/to_fpdf.yml'))
  
  def text(t)
    @text_element = true
    #t.gsub!(/\&#(\d{1,4})\;/, get_char($1.to_i))
    t.upcase! if get_option(:caps)
    @pdf.Write(@curr_line || get_default(:line), t)
  end
  
  [:h1, :h2, :h3, :h4, :h5, :h6, :p, :pre, :div, :code, :span, :b, :strong, :i, :em, :big, :small].each do |m|
    define_method("#{m}_open") do |opts|
      open_tag(m, opts)
      @pdf.Ln if paragraph?(m.to_s) && @text_element
      #@text_element = false
    end
    define_method("#{m}_closed") do 
      close_tag(m, paragraph?(m.to_s))
      @text_element = false
    end
  end
  
  [:ol, :ul].each do |m|
    define_method("#{m}_open") do |opts|
       open_tag(m, opts)
       @nested = -1 unless @nested
       @nested += 1
       @ordered = {} if m == :ol 
       @first_item = true
       @pdf.Ln if @nested > 0 || @text_element
       #@text_element = false
       list_margin(m, opts, @nested - 1) if @nested > 0
    end 
    define_method("#{m}_closed") do  
       @nested -= 1
       @ordered = nil
       #reset_margin(m) if @nested <= 0
       close_tag(m, @nested < 0)
    end
  end
    
  def li_open(opts)
    open_tag(:li_open, opts)
    list_margin(:li_open, opts, @nested) if @nested > -1
    @pdf.Ln unless @first_item
    @first_item = false
    if @ordered
       @ordered[@nested] = 0 unless @ordered[@nested]
       @ordered[@nested] += 1
       @pdf.Write(@curr_line, @ordered[@nested] + ".  ")
    else
       @pdf.Write(@curr_line, bullet + "  ")
   end
  end
  
  def li_closed
    #reset_margin(:li)
    close_tag(:li_closed)
  end
       
  def hr
    style = get_style(:hr)
    @pdf.Line(@pdf.GetX(), @pdf.GetY(), @pdf.GetX() + style[:length], @pdf.GetY())
  end
  
  def br
    @pdf.Ln
  end
   

  def a(opts)
    open_tag(:a, opts)
    @pdf.Write(@curr_line, opts[:text], opts[:href])
    close_tag(:a)
    #@pdf.Link(get_left_margin(:a, opts), @pdf.GetY(), get_default(:length), @curr_line, opts[:href])
  end
 
=begin
  def a_closed
    close_tag(:a_closed)
  end
=end
  
  
private 
  def open_tag(m, opts)
    opts['font-weight'.to_sym] = "B" if is_bold?(m) && opts['font-weight'].nil?
    opts['font-style'.to_sym] = "I" if is_italic?(m) && opts['font-style'].nil?
    opts['font-size'.to_sym] = (get_option('font-size'.to_sym) || get_default(:size)) + 1 if m == :big
    opts['font-size'.to_sym] = (get_option('font-size'.to_sym) || get_default(:size)) - 1 if m == :small
    set_pdf_style(m, opts)
    save_opts(opts)
  end
  
  def close_tag(m, linebreak = false)
    @pdf.Ln if linebreak
    reset_opts
    set_pdf_style
  end
  
  def list_margin(method, opts, nested)
    if opts['text-ident']
      @pdf.SetLeftMargin(opts['text-ident'])
    else 
      style = get_style(method)
      initial = style[:ident] || get_default(:ident)
      increment = style[:ident_inc] || get_default(:ident_inc)
      @pdf.SetLeftMargin(initial + nested * increment)
    end
  end
 
=begin
  def reset_margin(m)
    style = get_style(m)
    @pdf.SetLeftMargin(@prev_opts['text-ident'] || style[:ident] || get_default(:ident))
  end
=end

  def set_pdf_style(method = "", opts = {})
    style = get_style(method)
    prev_family =  get_option('font-family'.to_sym)
    prev_style = get_option('font-style'.to_sym)
    prev_weight = get_option('font-weight'.to_sym)
    prev_decoration = get_option('text-decoration'.to_sym)
    prev_size = get_option('font-size'.to_sym)
    @pdf.SetFont(opts['font-family'.to_sym] || prev_family || style[:family] || get_default(:family), get_font_style(opts['font-style'.to_sym], opts['font-weight'.to_sym], opts['text-decoration'.to_sym]) || get_font_style(prev_style, prev_weight, prev_decoration) || style[:style] || get_default(:style), opts['font-size'.to_sym] || prev_size || style[:size] || get_default(:size))
    @pdf.SetLeftMargin(opts['text-ident'.to_sym] || get_option('text-ident'.to_sym) || style[:ident] || get_default(:ident))
    color = get_color(opts[:color] || get_option(:color) || style[:color] || get_default(:color))
    #debugger if method == :span
    @pdf.SetTextColor(color[0], color[1], color[2])
    @curr_line = opts['line-height'.to_sym] || get_option('line-height'.to_sym) || style[:line] || get_default(:line)
    @curr_caps = opts[:caps] || get_option(:caps) || false
  end
  
  def get_color(color)
    begin
      #debugger
      if color.slice(0,0) == '#'
        arr = Array.new
        arr[0] = color.slice(1,2).hex
        arr[1] = color.slice(3,4).hex
        arr[2] = color.slice(5,6).hex
      else 
        arr = COLORS[color.upcase] || [0, 0 ,0]
      end
    rescue
      arr = [0, 0, 0]
    end
    return arr
  end
  
  def get_font_style(style, weight, decoration)
    unless style.nil? && weight.nil? && decoration.nil?
      (style || "") + (weight || "") + (decoration || "")
    end
  end
   
  def save_opts(opts)
    @curr_opts << opts
  end
  
  def reset_opts
    @curr_opts.pop
  end
   
  def is_bold?(m)
    m == :b || m == :strong
  end
  
  def is_italic?(m)
    m == :i || m == :strong || m == :em
  end
  
=begin
  
  def get_char(num)
    case num 
      when num == 8211
        endash
      when num == 8212
        emdash
      when num == 8482
        trademark
      when num == 8216 || 8217
        quote
      when num == 8220 || 8221
        dquote
      when num == 8364
        euro
      when num == 8226
        bullet
      when num == 8230
        ellipsis
      else
        num.chr
    end
  end
  
  def trademark
    153.chr
  end

  def registered
    174.chr
  end
  
  def copyright
    169.chr
  end
  
  def amp
    38.chr
  end
  
  def gt
    62.chr
  end
  
  def lt
    60.chr
  end
   
  def emdash
    151.chr
  end
  
  def endash
    150.chr
  end
  
  def quote
    39.chr
  end
  
  def dquote
    34.chr
  end
  
  def euro
    128.chr
  end
  
  def bullet
    149.chr
  end
  
  def elliplis
    133.chr
  end
=end   
 
end