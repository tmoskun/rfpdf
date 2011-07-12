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

require 'hpricot'
require 'formatters/to_fpdf'
require 'htmlentities'

module HTMLFormatter
  class Parser
        
    @@DEFAULT_LINE = 6
    @@DEFAULT_STYLE = ''
    @@DEFAULT_SIZE = 12
    @@DEFAULT_FAMILY = ''
    @@DEFAULT_IDENT = 10  
    @@DEFAULT_IDENT_INC = 5
    @@DEFAULT_COLOR = [0, 0, 0]
    @@DEFAULT_LENGTH = 200
            
    attr_accessor :styles  
                  
    def initialize(text, defaults = {})
      doc = Hpricot(text)
      @@decoder = HTMLEntities.new 
      @fragments = Array.new     #array of text fragments
      parse_document(doc) || []
      #p @fragments
      @defaults = {}
      set_defaults(defaults)
      @styles = {:a => {:color => 'blue', :style => 'U'}}  
    end
    
    def to_pdf(pdf)      
      @pdf = pdf
      @curr_opts = []
      @curr_lune = @@DEFAULT_LINE
      @curr_caps = false
      @text_element = false
      self.extend PDF_Formatter
      @fragments.each do |fragment|
        if fragment.instance_of?(Hash)
          tag = fragment.keys[0]
          fn = method(tag.to_sym)
          fn.call(fragment[tag])
        elsif fragment.kind_of?(String)
          fn = method(fragment.to_sym)
          fn.call
        end
      end
    end
      
    def set_style(tag, line = get_default(:line), style = get_default(:style), color = get_default(:color), size = get_default(:size), family = get_default(:family), ident = get_default(:ident), ident_inc = get_default(:ident_inc))
      @styles << {tag => {:line => line, :style => style, :color => color, :size => size, :family => family, :ident => ident, :ident_inc => ident_inc}}
    end
    
    def set_hr_style(line = get_default(:line), length = get_default(length))
      @styles << {:hr => {:length => length}}
    end
  
    def get_style(tag)
      @styles[tag] || {}
    end
   
    
private

    def parse_document(doc)
       body = doc.find_element("body")
       if body
          doc1.search("//body") do |node|
              parse_element(node)
          end
       else
          parse_children(doc)
       end
    end
    
    def parse_children(doc)
       doc.each_child do |e|
          parse_element(e)
       end
    end
    
    def parse_element(e)
      if e.text?
         text = e.to_html
         unless text.strip.empty?
            text.gsub!(/^\s*?( ?\S.*\S ?)\s*$/, '\1')
            parent = e.parent
            prev = e.previous_node
            nex = e.next_node
            if parent && (paragraph?(parent.name) || parent.name.nil?)
                text.gsub!(/^\s*(\S.*)$/, '\1') if prev.nil? || paragraph?(prev.name)
                text.gsub!(/^(.*\S)\s*/, '\1') if nex.nil? || paragraph?(nex.name)
            end
            @fragments << {"text" => @@decoder.decode(text)} unless text.strip.empty?
         end
      elsif e.elem?
         if e.empty?
            @fragments << e.name
         else
            attrs = {}
            caps = e.get_attribute("class") == 'caps'
            attrs.merge!(:caps => caps) if caps
            href = e.get_attribute("href")
            attrs.merge!(:href => href) if href
            attrs.merge!(get_attrs(e.get_attribute("style")))
            if e.name == "a"
               attrs.merge!(:text => e.inner_html)
               @fragments << {e.name => attrs}
            else
               @fragments << {"#{e.name}_open" => attrs}
               parse_children(e)
               @fragments << "#{e.name}_closed"
            end
         end
       end
    end
             
              
    def get_attrs(style)
        attrs = {}
        unless style.nil?
           for value in style.split(";")
             if value =~ /(.*):(.*)/
               attr = $2
               if $1 == 'font-weight'.to_sym && $2.upcase == 'BOLD'
                 attr = 'B'
               elsif $1 == 'font-style'.to_sym && $2.upcase == 'ITALIC'
                 attr = 'I'
               elsif $1 == 'text-decoration'.to_sym && $2.upcase == 'UNDERLINE'
                 attr = 'U'
               end
               attrs[$1.to_sym] = attr.strip unless attr.nil?
             end
           end
       end
       return attrs
    end
    
    def get_option(opt)
      @curr_opts.reverse_each do |opts|
        return opts[opt] unless opts[opt].nil?
      end
      return nil
    end
        
    def set_defaults(defaults)
       @defaults[:line] = defaults[:line] || @@DEFAULT_LINE
       @defaults[:color] = defaults[:color] || @@DEFAULT_COLOR
       @defaults[:style] = defaults[:style] || @@DEFAULT_STYLE
       @defaults[:size] = defaults[:size] || @@DEFAULT_SIZE
       @defaults[:family] = defaults[:family] || @@DEFAULT_FAMILY
       @defaults[:ident] = defaults[:ident] || @@DEFAULT_IDENT
       @defaults[:ident_inc] = defaults[:ident_inc] || @@DEFAULT_IDENT_INC
       @defaults[:length] = defaults[:length] || @@DEFAULT_LENGTH
    end
   
    def get_default(attr)
      @defaults[attr]
    end
        
    def paragraph?(tag)
      ["h1", "h2", "h3", "h4", "h5", "h6", "p", "pre", "div", "code", "ul", "ol", "li", "br", "hr"].include?(tag)
    end
    
    def bullet
      @@decoder.decode("&#8226;")
    end
             
  end
end
