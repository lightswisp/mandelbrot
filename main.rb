require "gosu"
require "complex"

module Modes 
  Julia      = 0b0001
  Mandelbrot = 0b0010
  Hsv        = 0b0100
  Rgb        = 0b1000
end

WIDTH = 900 
HEIGHT = WIDTH 
DIVISION_SCALE = 2 / ((WIDTH-1)/2.0)
MAX_ITERATIONS = 100 
RGB_ITERATIONS_RATIO = 255.0 / MAX_ITERATIONS

Pixel = Struct.new(
        :x, 
        :y,
        :color)

class Mandelbrot < Gosu::Window

  def initialize(mode)
    super WIDTH, HEIGHT
    self.caption = "mandelbrot test"
    @mode = mode
    @pixels = []
  end

  def transpose(x, y, cx, cy) 

    # Matrix A:
    # 
    # +---------------------+
    # | -2, 2 | 0, 2 | 2, 2 |
    # +-------+------+------+
    # | -2, 0 | 0, 0 | 2, 0 |
    # +-------+------+------+
    # | -2,-2 | 0,-2 | 2,-2 |
    # +-------+------+------+
    # 
    # Matrix B:
    # 
    # +---------------------+
    # | 0, 0  | 1, 0 | 2, 0 |
    # +-------+------+------+
    # | 0, 1  | 1, 1 | 2, 1 |
    # +-------+------+------+
    # | 0, 2  | 1, 2 | 2, 2 |
    # +-------+------+------+
    # 
    # The goal is to convert the MatrixB coordinate system to MatrixA
    # In MatrixA, x coordinate means the distance between the center (0,0)
    # In MatrixB, x coordinate means the distance between the left corner
    # So, in order to convert the x coordinate from B to A, we need to:
    #   1) Find the the center coordinate in MatrixB which is 1 ((matrix_width - 1) / 2)
    #   2) Substract current x coord from center coordinate, to find delta x
    #   3) Transpose the delta x to MatrixA world by multiplying with stepA
    # 
    # To convert the y coordinate do the following:
    #   1) Find the center coordinate in MatrixB, which is 1 ((matrix_height - 1) / 2)
    #   2) Substract (center_y - current_y) to find delta y
    #   3) Multiply delta y with stepA

    tx = (x - cx) * DIVISION_SCALE
    ty = (cy - y) * DIVISION_SCALE

    return [tx, ty]
  end

  def compute_color(alpha, iteration)
    #return COLOR_PALETTE[iteration]
    color = alpha << 24
    r = (RGB_ITERATIONS_RATIO * iteration).to_i << 16
    g = (RGB_ITERATIONS_RATIO * iteration).to_i << 8 
    b = (RGB_ITERATIONS_RATIO * iteration).to_i << 0 
    color |= r | g | b
    return color
  end

  def julia(x, y)
    c0 = Complex(-0.8, 0.156)
    c  = Complex(x,y)

    MAX_ITERATIONS.times do |i|
      if(c.abs > 2) 
        # outside of the julia set
        if (@mode & Modes::Hsv) == Modes::Hsv
          return Gosu::Color.from_hsv((360.0 / MAX_ITERATIONS) * i, 
                                      (1.0 / MAX_ITERATIONS) * i, 
                                      (1.0 / MAX_ITERATIONS) * i)
        else 
          color = compute_color(0xff, i)
          return Gosu::Color.argb(color)
        end
      else
        c = c**2 + c0
      end
    end
    return Gosu::Color.argb(0x00_000000)
  end

  def mandelbrot(x,y)
    c0 = Complex(x, y) 
    # we start from zero
    c = 0 

    MAX_ITERATIONS.times do |i|
      if(c.abs > 2) 
        # outside of the mandelbrot set
        if (@mode & Modes::Hsv) == Modes::Hsv
          return Gosu::Color.from_hsv((360.0 / MAX_ITERATIONS) * i, 
                                      (1.0 / MAX_ITERATIONS) * i, 
                                      (1.0 / MAX_ITERATIONS) * i)
        else 
          color = compute_color(0xff, i)
          return Gosu::Color.argb(color)
        end
      else
        c = c**2 + c0
      end
    end
    return Gosu::Color.argb(0x00_000000)
  end

  def precompute()
    cx = (WIDTH - 1) / 2.0
    cy = (HEIGHT - 1) / 2.0
    if (@mode & Modes::Mandelbrot) == Modes::Mandelbrot
      HEIGHT.times do |y|
        WIDTH.times do |x|
          x_transposed, y_transposed = transpose(x, y, cx, cy) 
          @pixels << Pixel.new(x, y, mandelbrot(x_transposed, y_transposed))
        end
      end
    else
      HEIGHT.times do |y|
        WIDTH.times do |x|
          x_transposed, y_transposed = transpose(x, y, cx, cy) 
          @pixels << Pixel.new(x, y, julia(x_transposed, y_transposed))
        end
      end
    end
  end

  def draw()
    @pixels.each do |pixel|
      Gosu.draw_rect(pixel.x, pixel.y, 1,1, pixel.color) 
    end
  end 

  def update()
    # nothing to update for now ;)
  end

end

m = Mandelbrot.new(Modes::Mandelbrot | Modes::Hsv)
m.precompute
m.show
