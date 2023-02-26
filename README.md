# cluster-1

This project uses a script to setup remote KinD clusters
to setup Open Cluster Management on them and joins three
managed clusters to the main Hub cluster.

It assumes you have four Ubuntu VMs with docker installed
and have already configured ssh-key based logins.  

Once your cluster is instantiated, you should see something
 like this;

 Installing built-in application-manager add-on to the Hub cluster...
Deploying application-manager add-on to namespaces open-cluster-management-agent-addon of managed cluster: node1.
Deploying application-manager add-on to namespaces open-cluster-management-agent-addon of managed cluster: node2.
Deploying application-manager add-on to namespaces open-cluster-management-agent-addon of managed cluster: node3.
Installing built-in governance-policy-framework add-on to the Hub cluster...
Deploying governance-policy-framework add-on to namespaces open-cluster-management-agent-addon of managed cluster: node1.
Deploying governance-policy-framework add-on to namespaces open-cluster-management-agent-addon of managed cluster: node2.
Deploying governance-policy-framework add-on to namespaces open-cluster-management-agent-addon of managed cluster: node3.
Deploying config-policy-controller add-on to namespaces open-cluster-management-agent-addon of managed cluster: node1.
Deploying config-policy-controller add-on to namespaces open-cluster-management-agent-addon of managed cluster: node2.
Deploying config-policy-controller add-on to namespaces open-cluster-management-agent-addon of managed cluster: node3.
Switched to context "kind-master".
policy.policy.open-cluster-management.io/policy-pod created
placementbinding.policy.open-cluster-management.io/binding-policy-pod created
placement.cluster.open-cluster-management.io/placement-policy-pod created
placement.cluster.open-cluster-management.io/placement-policy-pod patched
Completed Successfully - please wait while the components are activated...
<ManagedCluster>
└── node1
│   ├── application-manager
│   │   ├── <Status>
│   │   │   ├── Available -> true
│   │   │   ├── ManifestApplied -> true
│   │   │   ├── RegistrationApplied -> true
│   │   ├── <ManifestWork>
│   │       └── clusterroles.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management:application-manager (applied)
│   │       │   ├── aggregate-appsub-admin (applied)
│   │       └── clusterrolebindings.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management:application-manager (applied)
│   │       └── deployments.apps
│   │       │   ├── open-cluster-management-agent-addon/application-manager (applied)
│   │       └── services
│   │       │   ├── open-cluster-management-agent-addon/mc-subscription-metrics (applied)
│   │       └── serviceaccounts
│   │       │   ├── open-cluster-management-agent-addon/application-manager (applied)
│   │       └── customresourcedefinitions.apiextensions.k8s.io
│   │           └── helmreleases.apps.open-cluster-management.io (applied)
│   │           └── subscriptions.apps.open-cluster-management.io (applied)
│   │           └── subscriptionstatuses.apps.open-cluster-management.io (applied)
│   ├── config-policy-controller
│   │   ├── <Status>
│   │   │   ├── Available -> true
│   │   │   ├── ManifestApplied -> true
│   │   │   ├── RegistrationApplied -> true
│   │   ├── <ManifestWork>
│   │       └── clusterrolebindings.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management:config-policy-controller (applied)
│   │       └── deployments.apps
│   │       │   ├── open-cluster-management-agent-addon/config-policy-controller (applied)
│   │       └── roles.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management-agent-addon/config-policy-controller-leader (applied)
│   │       └── rolebindings.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management-agent-addon/config-policy-controller-leader (applied)
│   │       └── customresourcedefinitions.apiextensions.k8s.io
│   │       │   ├── configurationpolicies.policy.open-cluster-management.io (applied)
│   │       └── serviceaccounts
│   │       │   ├── open-cluster-management-agent-addon/config-policy-controller-sa (applied)
│   │       └── clusterroles.rbac.authorization.k8s.io
│   │           └── open-cluster-management:config-policy-controller (applied)
│   ├── governance-policy-framework
│       └── <Status>
│       │   ├── Available -> true
│       │   ├── ManifestApplied -> true
│       │   ├── RegistrationApplied -> true
│       └── <ManifestWork>
│           └── namespaces
│           │   ├── node1 (applied)
│           └── customresourcedefinitions.apiextensions.k8s.io
│           │   ├── policies.policy.open-cluster-management.io (applied)
│           └── serviceaccounts
│           │   ├── open-cluster-management-agent-addon/governance-policy-framework-sa (applied)
│           └── deployments.apps
│           │   ├── open-cluster-management-agent-addon/governance-policy-framework (applied)
│           └── roles.rbac.authorization.k8s.io
│           │   ├── open-cluster-management-agent-addon/governance-policy-framework-leader (applied)
│           │   ├── node1/open-cluster-management:governance-policy-framework (applied)
│           └── rolebindings.rbac.authorization.k8s.io
│               └── open-cluster-management-agent-addon/governance-policy-framework-leader (applied)
│               └── node1/open-cluster-management:governance-policy-framework (applied)
└── node2
│   ├── application-manager
│   │   ├── <Status>
│   │   │   ├── Available -> true
│   │   │   ├── ManifestApplied -> true
│   │   │   ├── RegistrationApplied -> true
│   │   ├── <ManifestWork>
│   │       └── customresourcedefinitions.apiextensions.k8s.io
│   │       │   ├── helmreleases.apps.open-cluster-management.io (applied)
│   │       │   ├── subscriptions.apps.open-cluster-management.io (applied)
│   │       │   ├── subscriptionstatuses.apps.open-cluster-management.io (applied)
│   │       └── clusterroles.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management:application-manager (applied)
│   │       │   ├── aggregate-appsub-admin (applied)
│   │       └── clusterrolebindings.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management:application-manager (applied)
│   │       └── deployments.apps
│   │       │   ├── open-cluster-management-agent-addon/application-manager (applied)
│   │       └── services
│   │       │   ├── open-cluster-management-agent-addon/mc-subscription-metrics (applied)
│   │       └── serviceaccounts
│   │           └── open-cluster-management-agent-addon/application-manager (applied)
│   ├── config-policy-controller
│   │   ├── <Status>
│   │   │   ├── Available -> true
│   │   │   ├── ManifestApplied -> true
│   │   │   ├── RegistrationApplied -> true
│   │   ├── <ManifestWork>
│   │       └── clusterroles.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management:config-policy-controller (applied)
│   │       └── clusterrolebindings.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management:config-policy-controller (applied)
│   │       └── deployments.apps
│   │       │   ├── open-cluster-management-agent-addon/config-policy-controller (applied)
│   │       └── roles.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management-agent-addon/config-policy-controller-leader (applied)
│   │       └── rolebindings.rbac.authorization.k8s.io
│   │       │   ├── open-cluster-management-agent-addon/config-policy-controller-leader (applied)
│   │       └── customresourcedefinitions.apiextensions.k8s.io
│   │       │   ├── configurationpolicies.policy.open-cluster-management.io (applied)
│   │       └── serviceaccounts
│   │           └── open-cluster-management-agent-addon/config-policy-controller-sa (applied)
│   ├── governance-policy-framework
│       └── <Status>
│       │   ├── Available -> true
│       │   ├── ManifestApplied -> true
│       │   ├── RegistrationApplied -> true
│       └── <ManifestWork>
│           └── deployments.apps
│           │   ├── open-cluster-management-agent-addon/governance-policy-framework (applied)
│           └── roles.rbac.authorization.k8s.io
│           │   ├── open-cluster-management-agent-addon/governance-policy-framework-leader (applied)
│           │   ├── node2/open-cluster-management:governance-policy-framework (applied)
│           └── rolebindings.rbac.authorization.k8s.io
│           │   ├── open-cluster-management-agent-addon/governance-policy-framework-leader (applied)
│           │   ├── node2/open-cluster-management:governance-policy-framework (applied)
│           └── namespaces
│           │   ├── node2 (applied)
│           └── customresourcedefinitions.apiextensions.k8s.io
│           │   ├── policies.policy.open-cluster-management.io (applied)
│           └── serviceaccounts
│               └── open-cluster-management-agent-addon/governance-policy-framework-sa (applied)
└── node3
    └── application-manager
    │   ├── <Status>
    │   │   ├── Available -> true
    │   │   ├── ManifestApplied -> true
    │   │   ├── RegistrationApplied -> true
    │   ├── <ManifestWork>
    │       └── serviceaccounts
    │       │   ├── open-cluster-management-agent-addon/application-manager (applied)
    │       └── customresourcedefinitions.apiextensions.k8s.io
    │       │   ├── helmreleases.apps.open-cluster-management.io (applied)
    │       │   ├── subscriptions.apps.open-cluster-management.io (applied)
    │       │   ├── subscriptionstatuses.apps.open-cluster-management.io (applied)
    │       └── clusterroles.rbac.authorization.k8s.io
    │       │   ├── open-cluster-management:application-manager (applied)
    │       │   ├── aggregate-appsub-admin (applied)
    │       └── clusterrolebindings.rbac.authorization.k8s.io
    │       │   ├── open-cluster-management:application-manager (applied)
    │       └── deployments.apps
    │       │   ├── open-cluster-management-agent-addon/application-manager (applied)
    │       └── services
    │           └── open-cluster-management-agent-addon/mc-subscription-metrics (applied)
    └── config-policy-controller
    │   ├── <Status>
    │   │   ├── Available -> true
    │   │   ├── ManifestApplied -> true
    │   │   ├── RegistrationApplied -> true
    │   ├── <ManifestWork>
    │       └── roles.rbac.authorization.k8s.io
    │       │   ├── open-cluster-management-agent-addon/config-policy-controller-leader (applied)
    │       └── rolebindings.rbac.authorization.k8s.io
    │       │   ├── open-cluster-management-agent-addon/config-policy-controller-leader (applied)
    │       └── customresourcedefinitions.apiextensions.k8s.io
    │       │   ├── configurationpolicies.policy.open-cluster-management.io (applied)
    │       └── serviceaccounts
    │       │   ├── open-cluster-management-agent-addon/config-policy-controller-sa (applied)
    │       └── clusterroles.rbac.authorization.k8s.io
    │       │   ├── open-cluster-management:config-policy-controller (applied)
    │       └── clusterrolebindings.rbac.authorization.k8s.io
    │       │   ├── open-cluster-management:config-policy-controller (applied)
    │       └── deployments.apps
    │           └── open-cluster-management-agent-addon/config-policy-controller (applied)
    └── governance-policy-framework
        └── <Status>
        │   ├── Available -> true
        │   ├── ManifestApplied -> true
        │   ├── RegistrationApplied -> true
        └── <ManifestWork>
            └── roles.rbac.authorization.k8s.io
            │   ├── open-cluster-management-agent-addon/governance-policy-framework-leader (applied)
            │   ├── node3/open-cluster-management:governance-policy-framework (applied)
            └── rolebindings.rbac.authorization.k8s.io
            │   ├── open-cluster-management-agent-addon/governance-policy-framework-leader (applied)
            │   ├── node3/open-cluster-management:governance-policy-framework (applied)
            └── namespaces
            │   ├── node3 (applied)
            └── customresourcedefinitions.apiextensions.k8s.io
            │   ├── policies.policy.open-cluster-management.io (applied)
            └── serviceaccounts
            │   ├── open-cluster-management-agent-addon/governance-policy-framework-sa (applied)
            └── deployments.apps
                └── open-cluster-management-agent-addon/governance-policy-framework (applied)
 