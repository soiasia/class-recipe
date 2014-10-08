class Card::RecipeCard < Card
  field :required_time, type: Fixnum, default: 0

  include Mongoid::Orderable
  embedded_in :recipe
  orderable column: :position

  scope :ordered_by_position, ->{order("position ASC")}

  class << self
    def updatable_columns
      super + [:position, :move_to, :required_time]
    end
  end
end
