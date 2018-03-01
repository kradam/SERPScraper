ActiveRecord::Base.establish_connection(
  adapter:  'mysql2', # or 'postgresql' or 'sqlite3'
  database: 'skaner',
  username: 'root',
  password: '',
  host:     'localhost'
)

class Domain < ActiveRecord::Base
   has_many :urls, dependent: :destroy
end

class Url < ActiveRecord::Base
   belongs_to :domain
   has_many :positions
end

class Position  < ActiveRecord::Base
  belongs_to :search
  belongs_to :phrase
  belongs_to :url    
end

class Search  < ActiveRecord::Base
  has_many :positions
end

class Phrase  < ActiveRecord::Base
  has_many :positions
end