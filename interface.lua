
struct{ name = "minhaStruct",
	fields = {{name = "nome",type = "string"},
	{name = "peso",type = "double"},
	{name = "idade",type = "int"},
	}
}


interface{ name = "minhaInt",
	methods = {
		bar = {
			resulttype = "double",
			args = {
			{direction = "in",
			type = "double"},
			{direction = "in",
			type = "string"},
			{direction = "in",
			type = "minhaStruct"},
			{direction = "inout",
			type = "int"},
			}
		},
		foo = {
                        resulttype = "double",
                        args = {
                        {direction = "in",
                         type = "double"},
                        {direction = "in",
                        type = "double"},
                        {direction = "out",
                        type = "string"},
                        },

               },
               boo = {
                 resulttype = "void",
                 args = {
                         { direction = "inout",
                          type = "double"},
                        },
               },


	}}	
