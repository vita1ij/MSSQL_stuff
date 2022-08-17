

declare @deleteFromTable varchar(max) = 'table_name'
declare @condition varchar(max) = 'column_id = @id'
declare @tbl int
select @tbl = object_id from sys.tables where name = @deleteFromTable

;with x_foreign_keys(base_tbl_id, base_tbl, base_column_id, base_column, dependant_tbl_id, dependant_tbl, dependant_column_id, dependant_column)
as
(
	select 
		referenced_object_id,
		convert(varchar(max),child_table.name),
		child_column.column_id,
		convert(varchar(max),child_column.name),
		parent_table.object_id,
		convert(varchar(max),parent_table.name),
		parent_column.column_id,
		convert(varchar(max),parent_column.name)
	from sys.foreign_key_columns fkc
	join sys.tables child_table on child_table.object_id = fkc.referenced_object_id
	join sys.columns parent_column on parent_column.column_id = parent_column_id and parent_column.object_id = fkc.parent_object_id 
	join sys.columns child_column  on child_column.column_id = referenced_column_id and child_column.object_id = fkc.referenced_object_id
	join sys.tables parent_table on parent_table.object_id = fkc.parent_object_id

)
,x_foreign_joins(base_tbl, dependant_tbl, join_script)
as
(
	select 
		base_tbl,
		dependant_tbl,
		(select 
			' or ###.' + base_column + '= $$$.' + dependant_column 
		from 
			x_foreign_keys y 
		where 
			x.base_column_id = y.base_column_id 
			and x.base_tbl_id = y.base_tbl_id 
			and x.dependant_tbl_id = y.dependant_tbl_id 
		for xml path('')
		) 
	from x_foreign_keys x
		group by 
		base_tbl,
		base_tbl_id, 
		base_column,
		base_column_id, 
		dependant_tbl,
		dependant_tbl_id 
)
,x_foreign_joins_formatted(base_tbl, dependant_tbl, join_script)
as
(
	select
		base_tbl, 
		dependant_tbl, 
		RIGHT(join_script, LEN(join_script)-4)
	from x_foreign_joins
)
,delete_order(rn_parent, rn_txt, tbl, script, script_tail, tbl_path)
as
(
	select 
		convert(varchar(max),''), 
		convert(varchar(max),'t1'), 
		@deleteFromTable,
		convert(varchar(max),'delete ' + @deleteFromTable + ' where ' + @condition),
		convert(varchar(max),' where ' + @condition),
		cast('|' as varchar(max)) + @deleteFromTable + '|'
	union all

	select 
		rn_txt,
		rn_txt + '_' + convert(varchar(max),row_number() over(order by dependant_tbl)),
		dependant_tbl,
		convert(varchar(max),'delete ' + rn_txt + '_' + convert(varchar(max),row_number() over(order by dependant_tbl)) 
			+ ' from ' + dependant_tbl + ' as ['+rn_txt + '_' + convert(varchar(max),row_number() over(order by dependant_tbl))+'] join ' 
			+ base_tbl + ' as ['+rn_txt+'] ON ' 
			+ REPLACE(REPLACE(join_script,'###',rn_txt),'$$$',rn_txt + '_' + convert(varchar(max),row_number() over(order by dependant_tbl))) + ' ' 
			+ script_tail),
		convert(varchar(max),' join ' + base_tbl + ' as ['+rn_txt+'] ON ' 
		+ REPLACE(REPLACE(join_script,'###',rn_txt),'$$$',rn_txt + '_' + convert(varchar(max),row_number() over(order by dependant_tbl))) + ' ' 
		+ script_tail),
		tbl_path + dependant_tbl + '|'
	from delete_order do
	join x_foreign_joins_formatted on tbl= base_tbl
	where dependant_tbl <> base_tbl
		and tbl_path not like ('%|' + base_tbl + '|' + dependant_tbl + '|%')
)
select * 
from delete_order
order by rn_txt desc