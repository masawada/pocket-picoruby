# Raises after a short countdown, to check that exceptions reach the screen.

3.downto(1) do |n|
  puts "boom in #{n}..."
  sleep 0.5
end

def boom(depth)
  raise ArgumentError, "boom from boom.rb" if depth == 0
  boom(depth - 1)
end

boom(2)
