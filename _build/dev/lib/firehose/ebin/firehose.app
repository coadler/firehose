{application,firehose,
             [{applications,[kernel,stdlib,elixir,logger,httpoison,amqp,
                             websocket_client,gen_stage,poison]},
              {description,"firehose"},
              {modules,['Elixir.Firehose.Application',
                        'Elixir.Firehose.Discord.Client',
                        'Elixir.Firehose.Discord.Utility',
                        'Elixir.Firehose.Error','Elixir.Firehose.Gauge',
                        'Elixir.Firehose.Nozzle.AMQP','Elixir.Firehose.Pump']},
              {registered,[]},
              {vsn,"0.1.0"},
              {mod,{'Elixir.Firehose.Application',[]}}]}.