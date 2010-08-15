module Arel
  module Visitors
    class ToSql
      def initialize engine
        @engine     = engine
        @connection = nil
      end

      def accept object
        @connection = @engine.connection
        visit object
      end

      private
      def visit_Arel_Nodes_UpdateStatement o
        [
          "UPDATE #{visit o.relation}",
          ("SET #{o.values.map { |column,value|
              "#{quote_column_name(column.name)} = #{quote visit value}"
            }.join ', '}" if o.values),
          ("WHERE #{o.wheres.map { |x| visit x }.join ' AND '}" unless o.wheres.empty?)
        ].compact.join ' '
      end

      def visit_Arel_Nodes_InsertStatement o
        [
          "INSERT INTO #{visit o.relation}",

          ("(#{o.columns.map { |x|
                quote_column_name x.name
            }.join ', '})" unless o.columns.empty?),

          ("VALUES (#{o.values.map { |value|
            value ? quote(visit(value)) : 'NULL'
          }.join ', '})" unless o.values.empty?),

        ].compact.join ' '
      end

      def visit_Arel_Nodes_SelectStatement o
        [
          o.cores.map { |x| visit x }.join,
          ("LIMIT #{o.limit}" if o.limit)
        ].compact.join ' '
      end

      def visit_Arel_Nodes_SelectCore o
        [
          "SELECT #{o.projections.map { |x| visit x }.join ', '}",
          ("FROM #{o.froms.map { |x| visit x }.join ', ' }" unless o.froms.empty?),
          ("WHERE #{o.wheres.map { |x| visit x }.join ' AND ' }" unless o.wheres.empty?)
        ].compact.join ' '
      end

      def visit_Arel_Table o
        quote_table_name o.name
      end

      def visit_Arel_Nodes_Equality o
        "#{visit o.left} = #{visit o.right}"
      end

      def visit_Arel_Attributes_Attribute o
        "#{quote_table_name o.relation.name}.#{quote_column_name o.name}"
      end
      alias :visit_Arel_Attributes_Integer :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attributes_Attribute

      def visit_Fixnum o; o end
      alias :visit_Time :visit_Fixnum
      alias :visit_String :visit_Fixnum
      alias :visit_Arel_Nodes_SqlLiteral :visit_Fixnum
      alias :visit_Arel_SqlLiteral :visit_Fixnum # This is deprecated

      DISPATCH = {}
      def visit object
        send "visit_#{object.class.name.gsub('::', '_')}", object
        #send DISPATCH[object.class], object
      end

      private_instance_methods(false).each do |method|
        method = method.to_s
        next unless method =~ /^visit_(.*)$/
        const = $1.split('_').inject(Object) { |m,s| m.const_get s }
        DISPATCH[const] = method
      end

      def quote value, column = nil
        @connection.quote value, column
      end

      def quote_table_name name
        @connection.quote_table_name name
      end

      def quote_column_name name
        @connection.quote_column_name name
      end
    end
  end
end
