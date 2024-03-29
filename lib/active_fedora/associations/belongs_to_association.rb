module ActiveFedora
  module Associations
    class BelongsToAssociation < AssociationProxy #:nodoc:

      def create(attributes = {})
        replace(@reflection.create_association(attributes))
      end

      def build(attributes = {})
        replace(@reflection.build_association(attributes))
      end

      def replace(record)
        if record.nil?
          remove_matching_property_relationship
        else
          raise_on_type_mismatch(record)

          remove_matching_property_relationship

          @target = (AssociationProxy === record ? record.target : record)
          @owner.add_relationship(@reflection.options[:property], record) unless record.new_record?
          @updated = true
        end

        loaded
        record
      end

      private
        def find_target
          pid = @owner.ids_for_outbound(@reflection.options[:property])
          return if pid.empty?          
          class_name = @reflection.options[:class_name] ? @reflection.options[:class_name] : @reflection.class_name
          query = construct_query(pid, class_name)    
          solr_result = SolrService.query(query)
          puts 'match2'
          return ActiveFedora::SolrService.reify_solr_results(solr_result).first
        end

        def construct_query pid, class_name
          if class_name && class_name != "ActiveFedora::Base"
            clauses = {}  
            clauses[:has_model] = class_name.constantize.to_class_uri
            query = ActiveFedora::SolrService.construct_query_for_rel(clauses) + " AND (" + ActiveFedora::SolrService.construct_query_for_pids(pid) + ")"
          else
            query = ActiveFedora::SolrService.construct_query_for_pids(pid)
          end
        end

        def remove_matching_property_relationship
          class_name = @reflection.options[:class_name] ? @reflection.options[:class_name] : @reflection.class_name
          ids = @owner.ids_for_outbound(@reflection.options[:property])
          return if ids.empty? 
          ids.each do |id|
            result = SolrService.query(ActiveFedora::SolrService.construct_query_for_pids([id]))
            puts 'match3'
            hit = ActiveFedora::SolrService.reify_solr_results(result).first
            # We remove_relationship on subjects that match the same class, or if the subject is nil 
            if hit.class.to_s == class_name || hit.nil?
              @owner.remove_relationship(@reflection.options[:property], hit)
            end
          end
        end

        def foreign_key_present
          !@owner.send(@reflection.primary_key_name).nil?
        end

    end
  end
end
