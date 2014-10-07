class Project
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Slug
  include Figurable
  include Commentable
  include Contributable
  include Taggable
  include Likable
  include Searchable

  searchable_field :name
  searchable_field :title
  searchable_field :description
  searchable_field :is_private, type: :boolean
  searchable_field :owner_id
  slug :name, scope: :owner_id

  field :license, type: :integer
  field :scale, type: :integer
  field :age, type: :integer
  field :subject, type: :integer

  has_many :derivatives, class_name: Project.name, inverse_of: :original
  belongs_to :original, class_name: Project.name, inverse_of: :derivatives
  belongs_to :owner, polymorphic: true
  embeds_many :usages, class_name: Card::Usage.name, cascade_callbacks: true
  embeds_one :recipe, autobuild: true, cascade_callbacks: true
  embeds_one :note, autobuild: true, cascade_callbacks: true

  after_initialize ->{self.name = SecureRandom.uuid, self.license = 0}, if: ->{new_record? && name.blank?}
  after_create :ensure_a_figure_exists
  after_create :create_recipe_and_note

  validates :name, presence: true, name_format: true
  validates :name, uniqueness: {scope: [:owner_id, :owner_type]}
  validates :title, presence: true

  index "note.num_cards" => 1
  scope :noted, ->{where :"note.num_cards".gt => 0}

  accepts_nested_attributes_for :usages

  paginates_per 12

  searchable do
    text :name
    text :title
    text :description
    string :owner_type
    string :owner_id
    boolean :is_private

    text :tags do
      tags.map { |tag| tag.name }.flatten
    end

    text :recipe do
      self.recipe.recipe_cards.map do |card|
        Card.searchable_fields.map do |col|
          card.send col
        end
      end.flatten
    end

    text :owner do
      (self.owner.class)::FULLTEXT_SEARCHABLE_COLUMNS.map do |col|
        self.owner.send col
      end
    end
  end

  def fork_for! owner
    dup.tap do |project|
      project.id = BSON::ObjectId.new
      project.owner = owner
      project.original = self
      names = owner.projects.pluck :name
      _name = name.dup
      if names.include? _name
        _name << "-1"
        _name.sub!(/(\d+)$/, "#{$1.to_i + 1}") while names.include? _name
      end
      project.name = _name
      project.save!
      project.recipe = recipe.dup_document
      project.figures = figures.map{|a| a.dup_document}
      project.usages = []
      project.note.note_cards = []
      begin
        project.save!
      rescue Exception => e
        project.destroy
        raise
      end
    end
  end

  def collaborators
    User.where("collaborations.project_id" => id)
  end

  def licenses
    ["by", "by-sa", "by-nc", "by-nc-sa"]
  end

  def subjects
    [
      ["ttbicon/sub_art.png", "Art"],
      ["ttbicon/sub_it.png", "Information Technologoy"],
      ["ttbicon/sub_koku.png", "Reading & Writing"],
      ["ttbicon/sub_lang.png", "Language"],
      ["ttbicon/sub_math.png", "Mathematics"],
      ["ttbicon/sub_mu.png", "Music"],
      ["ttbicon/sub_PE.png", "Physical Education"],
      ["ttbicon/sub_sci.png", "Science"],
      ["ttbicon/sub_soci.png", "Social"],
      ["ttbicon/sub_tech.png", "Technologoy"],
      ["ttbicon/sub_other.png", "Other"]
    ]
  end

  def scales
    [
      ["ttbicon/Scale/scale1-5.png", "for 1 - 5 peoples"],
      ["ttbicon/Scale/scale5-10.png", "for 5 - 10 peoples"],
      ["ttbicon/Scale/scale10-30.png", "for 10 - 30 peoples"],
      ["ttbicon/Scale/scale30.png", "over 30 peoples"]
    ]
  end

  def ages
    [
      ["ttbicon/Age/age_003.png", "for Ages 3 and up"],
      ["ttbicon/Age/age_007.png", "for Ages 7 and up"],
      ["ttbicon/Age/age_009.png", "for Ages 9 and up"],
      ["ttbicon/Age/age_013.png", "for Ages 13 and up"],
      ["ttbicon/Age/age_016.png", "for Ages 16 and up"],
      ["ttbicon/Age/age_018.png", "for Ages 18 and up"],
      ["ttbicon/Age/age_021.png", "for Ages 21 and up"],
      ["ttbicon/Age/age_060.png", "for Ages 60 and up"],
      ["ttbicon/Age/age_999.png", "for Everyone"]
    ]
  end

  class << self
    def updatable_columns
      [:name, :title, :description, :owner_id, :owner_type, :is_private, :license, :subject, :scale, :age,
       usages_attributes: Card::Usage.updatable_columns,
       figures_attributes: Figure.updatable_columns,
       likes_attributes: Like.updatable_columns,
      ]
    end
  end

  private
  def ensure_a_figure_exists
    figures.create if figures.none?
  end

  def create_recipe_and_note
    create_recipe
    create_note
  end
end
